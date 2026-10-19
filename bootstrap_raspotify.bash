#!/usr/bin/env bash
# Finish a flashed Raspberry Pi OS installation on the Pi itself.
# Download with curl -fsSL -o bootstrap_raspotify.bash URL, then:
#   sudo bash bootstrap_raspotify.bash --name 'Living Room'
# Also supports: curl -fsSL URL | sudo -n bash -s -- --name 'Living Room'
# Downloading successfully before executing is preferred. Never run from cloud-init.
# All definitions precede the entry point so piped input is parsed before use.

# Set the ALSA card ID shown by aplay -l (for example, CI1), not its numeric index.
USB_AUDIO_CARD_ID="CI1"

# Raspotify discovery TCP port, also allowed by the firewall (1025-65535).
ZEROCONF_PORT=24879

# Wait for cloud-init, package locks and post-reboot readiness (1-3600 seconds).
WAIT_TIMEOUT=600

usage() {
	cat <<'EOF'
Usage: sudo bash bootstrap_raspotify.bash [options]
Run on a Raspberry Pi 4/5-family device with Raspberry Pi OS/Debian 13+.

  --name NAME                 Spotify name (default: raspotify (<hostname>))
  --dry-run                   Inspect and describe; make no provisioning changes
  --no-upgrade                Skip the full system upgrade
  --no-firewall               Skip firewall management
  --no-ssh-hardening          Skip SSH configuration
  --no-unattended-upgrades    Skip automatic-update configuration
  --no-wifi-powersave-fix     Skip Wi-Fi profile changes
  --no-volatile-journal       Skip journald configuration
  --watchdog                  Enable systemd's hardware watchdog
  --update-eeprom             Apply an EEPROM update from the configured channel
  --reboot                    Reboot if needed, after access confirmation
  -h, --help

Playback always uses the maximum bitrate: 320 kbps.
Set USB_AUDIO_CARD_ID near the top of the script to select the USB audio interface.
Set ZEROCONF_PORT there to choose the discovery TCP port (default: 24879).
Set WAIT_TIMEOUT there to choose the readiness/lock wait in seconds (default: 600).
--no-* skips management; it does not reverse a previous run.
Access changes have a ten-minute rollback timer. Confirm from a NEW SSH
connection using the command printed during provisioning. No stdin prompts.
Logs: /var/log/pi-setup.log   Status: /var/lib/pi-setup/last-run
EOF
}

defaults() {
	NAME=""
	DRY_RUN=0 UPGRADE=1 FIREWALL=1 SSH_HARDENING=1 UNATTENDED=1
	WIFI_FIX=1 VOLATILE_JOURNAL=1 WATCHDOG=0 EEPROM=0
	REBOOT=0
	LOG=/var/log/pi-setup.log
	STATE_DIR=/var/lib/pi-setup
	ACCESS_DIR=/run/pi-setup-access
	ACCESS_LOCK=/run/pi-setup-access.lock
	REPO_URL=https://dtcooper.github.io/raspotify
	# Reviewed against the upstream repository key, October 2026.
	REPO_FINGERPRINT=2CC9B80F5AE2B7ACEFF2BA3209146F2F7953A455
	RUN_DIR="" RUN_ID="" BACKUP_DIR="" LOGIN_USER="" ORIGINAL_SSH=""
	ALSA_DEVICE="" ALSA_CARD="" ALSA_CARD_DIR="" AUDIO_FORMAT=""
	REBOOT_NEEDED=0 FILE_CHANGED=0 PROBE_STOPPED=0 WARNINGS=0 EEPROM_HELD=0
	DISABLED_SERVICES="" CURRENT_TEMP="" SSH_UNIT=""
}

status() { printf '[%s] %s\n' "$1" "$2"; }
warn() { WARNINGS=$((WARNINGS + 1)); status warning "$*"; }
die() { status failed "$*" >&2; exit 1; }
usage_error() { printf 'error: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

need_value() {
	[[ $# -ge 2 && -n $2 && $2 != --* ]] || usage_error "$1 requires a value"
}

parse_args() {
	while (( $# )); do
		case $1 in
			--name) need_value "$@"; NAME=$2; shift 2 ;;
			--dry-run) DRY_RUN=1; shift ;;
			--no-upgrade) UPGRADE=0; shift ;;
			--no-firewall) FIREWALL=0; shift ;;
			--no-ssh-hardening) SSH_HARDENING=0; shift ;;
			--no-unattended-upgrades) UNATTENDED=0; shift ;;
			--no-wifi-powersave-fix) WIFI_FIX=0; shift ;;
			--no-volatile-journal) VOLATILE_JOURNAL=0; shift ;;
			--watchdog) WATCHDOG=1; shift ;;
			--update-eeprom) EEPROM=1; shift ;;
			--reboot) REBOOT=1; shift ;;
			-h|--help) usage; exit 0 ;;
			*) usage_error "unknown argument: $1" ;;
		esac
	done
	if [[ ! $ZEROCONF_PORT =~ ^[1-9][0-9]{3,4}$ ]] ||
		(( ZEROCONF_PORT <= 1024 || ZEROCONF_PORT > 65535 )); then
		usage_error 'ZEROCONF_PORT must be between 1025 and 65535'
	fi
	if [[ ! $WAIT_TIMEOUT =~ ^[1-9][0-9]{0,3}$ ]] || (( WAIT_TIMEOUT > 3600 )); then
		usage_error 'WAIT_TIMEOUT must be between 1 and 3600 seconds'
	fi
	[[ $USB_AUDIO_CARD_ID =~ ^[[:alnum:]_-]+$ ]] || usage_error 'USB_AUDIO_CARD_ID must contain a valid ALSA card ID'
	[[ ! $NAME =~ [[:cntrl:]] ]] || usage_error '--name cannot contain control characters'
	(( ${#NAME} <= 128 )) || usage_error '--name is too long (maximum 128 characters)'
}

# sudo commonly strips SSH_CONNECTION. Read it from the process ancestry instead;
# never evaluate environment strings as shell code.
ssh_connection() {
	local pid=$$ connection depth=0
	while [[ $pid =~ ^[0-9]+$ ]] && (( pid > 1 && depth < 32 )); do
		connection=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null |
			awk '/^SSH_CONNECTION=/ {sub(/^SSH_CONNECTION=/, ""); print; exit}') || connection=""
		if [[ -n $connection ]]; then printf '%s\n' "$connection"; return; fi
		pid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null) || break
		depth=$((depth + 1))
	done
	printf '%s\n' "${SSH_CONNECTION:-}"
}

check_platform() {
	[[ $(uname -s) == Linux ]] || die 'run this script on the Raspberry Pi, not on the Mac'
	(( BASH_VERSINFO[0] >= 5 )) || die 'Bash 5 or newer is required'
	(( EUID == 0 )) || die 'run with sudo bash, or pipe into sudo -n bash -s --'
	local cmd model version architecture
	for cmd in systemctl systemd-run apt-get dpkg-query flock timeout curl awk sed grep \
		findmnt sha256sum ss stat install mktemp; do
		have "$cmd" || die "missing prerequisite: $cmd"
	done
	[[ -d /run/systemd/system ]] || die 'systemd must be running'
	[[ -r /proc/device-tree/model ]] || die 'no Raspberry Pi device-tree model found'
	model=$(tr -d '\0' < /proc/device-tree/model)
	case $model in
		'Raspberry Pi 4'*|'Raspberry Pi 5'*|'Raspberry Pi Compute Module 4'*|'Raspberry Pi Compute Module 5'*) ;;
		*) die "unsupported model: $model" ;;
	esac
	# This is a root-owned OS file, not downloaded configuration.
	# shellcheck disable=SC1091
	. /etc/os-release
	case " ${ID:-} ${ID_LIKE:-} " in *' debian '*|*' raspbian '*) ;; *) die 'a Debian-compatible OS is required' ;; esac
	version=${VERSION_ID:-0}; version=${version%%.*}
	if [[ ! $version =~ ^[0-9]{1,3}$ ]] || (( 10#$version < 13 )); then
		die 'Debian/Raspberry Pi OS 13 (Trixie) or newer is required'
	fi
	architecture=$(dpkg --print-architecture)
	case $architecture in arm64|armhf) ;; *) die "unsupported architecture: $architecture" ;; esac
	status ok "$model; ${PRETTY_NAME:-$ID}; $architecture"
	[[ -n $NAME ]] || NAME="raspotify ($(hostname))"
}

wait_for_cloud_init() {
	have cloud-init || die 'cloud-init is absent; this does not match the expected flash image'
	local rc=0
	timeout "$WAIT_TIMEOUT" cloud-init status --wait --long </dev/null || rc=$?
	if (( rc != 0 )); then
		status failed "cloud-init did not complete successfully (exit $rc)"
		tail -n 60 /var/log/cloud-init-output.log /var/log/cloud-init.log 2>/dev/null || true
		die 'resolve cloud-init errors before provisioning; do not run this script from cloud-init'
	fi
	status ok 'cloud-init completed'
}

preflight() {
	local free_kb options endpoint
	options=$(findmnt -n -o OPTIONS /)
	[[ ,$options, != *,ro,* ]] || die 'the root filesystem is read-only'
	free_kb=$(df -Pk / | awk 'END {print $4}')
	(( free_kb >= 1048576 )) || die 'at least 1 GiB of free root-filesystem space is required'
	(( $(date +%Y) >= 2025 )) || die 'the system clock is incorrect; fix time synchronization first'
	for endpoint in https://deb.debian.org/debian/ https://archive.raspberrypi.com/debian/ "$REPO_URL/"; do
		curl -fsSL --connect-timeout 10 --max-time 30 -o /dev/null "$endpoint" ||
			die "DNS/TLS/repository connectivity failed: $endpoint"
	done
	if (( SSH_HARDENING )); then
		if [[ -z $LOGIN_USER || $LOGIN_USER == root ]] || ! id "$LOGIN_USER" >/dev/null 2>&1; then
			die 'SSH hardening requires invocation via sudo from a non-root account (or --no-ssh-hardening)'
		fi
	fi
	if (( SSH_HARDENING || FIREWALL )); then
		/usr/sbin/sshd -t || die 'existing SSH configuration is invalid'
	fi
	status ok 'storage, clock, DNS and repository connectivity'
}

report_hardware() {
	local interface path value flags label bit
	status ok "hostname: $(hostname); addresses: $(hostname -I)"
	ip -brief address
	ip route show default
	if have nmcli; then nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status; fi
	if have iw; then
		while IFS= read -r interface; do
			[[ -n $interface ]] || continue
			status ok "Wi-Fi: $interface (frequency in MHz identifies the band)"
			iw dev "$interface" link || true
			iw dev "$interface" info || true
			iw dev "$interface" get power_save || true
		done < <(iw dev | awk '$1 == "Interface" {print $2}')
	else status skipped 'Wi-Fi diagnostics unverified: iw is not installed'; fi
	value=$(find /sys/class/bluetooth -maxdepth 1 -name 'hci*' -printf '%f ' 2>/dev/null) || value=""
	status ok "Bluetooth controllers: ${value:-none registered}"
	if [[ -r /proc/asound/cards ]]; then cat /proc/asound/cards; else warn 'no ALSA cards are registered'; fi
	if have aplay; then aplay -l || true; else status skipped 'PCM diagnostics unverified: alsa-utils is not installed'; fi
	status ok "kernel command line: $(cat /proc/cmdline)"
	for path in /sys/module/usbcore/parameters/autosuspend /sys/bus/usb/devices/*/power/control \
		/sys/devices/system/cpu/cpufreq/policy*/scaling_governor \
		/sys/class/leds/*/trigger /sys/class/leds/*/brightness /sys/class/drm/card*-*/status \
		/sys/class/drm/card*-*/enabled /sys/class/thermal/thermal_zone*/temp; do
		[[ -r $path ]] || continue
		printf '  %s: %s\n' "$path" "$(cat "$path")"
	done
	status ok "root mount options: $(findmnt -n -o OPTIONS /)"
	if have vcgencmd && value=$(vcgencmd get_throttled 2>/dev/null); then
		flags=${value#*=}
		if [[ $flags =~ ^0x[[:xdigit:]]+$ ]]; then
			status ok "power/throttling flags: $flags"
			for bit in 0 1 2 3 16 17 18 19; do
				case $bit in
					0) label='current undervoltage' ;; 1) label='current frequency cap' ;;
					2) label='currently throttled' ;; 3) label='current soft temperature limit' ;;
					16) label='undervoltage occurred since boot' ;; 17) label='frequency cap occurred since boot' ;;
					18) label='throttling occurred since boot' ;; 19) label='soft temperature limit occurred since boot' ;;
				esac
				if (( flags & (1 << bit) )); then warn "$label"; fi
			done
		fi
		value=$(vcgencmd get_config int 2>/dev/null | grep '^usb_max_current_enable=' || true)
		status ok "USB current configuration: ${value:-not exposed; unverified}"
	else status skipped 'power/firmware diagnostics unverified: vcgencmd is unavailable'; fi
}

select_audio() {
	local card id pcm
	local cards=() devices=()
	for card in /proc/asound/card[0-9]*; do
		[[ -r $card/id ]] || continue
		id=$(cat "$card/id")
		[[ $id == "$USB_AUDIO_CARD_ID" ]] || continue
		cards+=("$card")
	done
	if (( ${#cards[@]} != 1 )); then
		cat /proc/asound/cards 2>/dev/null || true
		die "expected one card with ID $USB_AUDIO_CARD_ID, found ${#cards[@]}; check the connection and USB_AUDIO_CARD_ID in the script"
	fi
	ALSA_CARD_DIR=${cards[0]}
	ALSA_CARD=$(cat "$ALSA_CARD_DIR/id")
	# snd-usb-audio exposes the USB vendor/product IDs in this procfs entry.
	[[ -r $ALSA_CARD_DIR/usbid ]] || die "configured card $ALSA_CARD is not a USB audio interface"
	for pcm in "$ALSA_CARD_DIR"/pcm*p; do
		[[ -d $pcm ]] || continue
		pcm=${pcm##*/pcm}; devices+=("${pcm%p}")
	done
	(( ${#devices[@]} == 1 )) || die "card $ALSA_CARD has ${#devices[@]} playback PCMs; automatic PCM selection would be ambiguous"
	ALSA_DEVICE="hw:CARD=$ALSA_CARD,DEV=${devices[0]}"
	status ok "selected audio device: $ALSA_DEVICE"
}

dry_run() {
	wait_for_cloud_init
	preflight
	report_hardware
	select_audio
	status skipped 'dry-run: audio probing and package-dependent validation are unverified'
	(( UPGRADE == 0 )) || status changed 'would update package indexes and full-upgrade the system'
	status changed 'would verify the Raspotify repository key, install dependencies and converge Raspotify configuration'
	status changed "would use $NAME, 320 kbps, $ALSA_DEVICE and TCP $ZEROCONF_PORT"
	(( WIFI_FIX == 0 )) || status changed 'would disable power saving in managed Wi-Fi profiles'
	(( UNATTENDED == 0 )) || status changed 'would schedule APT refresh at 04:00 and security upgrades at 04:30, local time'
	(( VOLATILE_JOURNAL == 0 )) || status changed 'would configure capped volatile journaling'
	(( WATCHDOG == 0 )) || status changed 'would check ownership and enable a hardware watchdog'
	(( EEPROM == 0 )) || status changed 'would check and apply an available EEPROM update'
	status changed 'would run apt-get -y autoremove'
	(( SSH_HARDENING == 0 )) || status changed 'would validate and harden SSH with timed rollback'
	(( FIREWALL == 0 )) || status changed 'would validate firewall ownership and install a dedicated nftables table with timed rollback'
	status skipped 'no provisioning changes made; ordinary OS/SSH logging may still occur'
}

secure_directory() {
	local directory=$1
	[[ ! -L $directory ]] || die "refusing symlink: $directory"
	if [[ -e $directory ]]; then
		[[ -d $directory && $(stat -c %u "$directory") == 0 ]] || die "not a root-owned directory: $directory"
	fi
	install -d -m 0700 "$directory"
}

backup_file() {
	local path=$1
	[[ -e $path ]] || return 0
	if [[ ! -e $BACKUP_DIR$path ]]; then
		install -d -m 0700 "$(dirname "$BACKUP_DIR$path")"
		cp -a -- "$path" "$BACKUP_DIR$path"
	fi
}

# Reads content from a heredoc or generated file, never from the script's stdin.
# Always returns success for an unchanged file; FILE_CHANGED carries the result.
write_file() {
	local path=$1 mode=$2
	FILE_CHANGED=0
	[[ ! -L $path ]] || die "refusing to replace symlink: $path"
	if [[ ! -d $(dirname "$path") ]]; then install -d -m 0755 "$(dirname "$path")"; fi
	CURRENT_TEMP=$(mktemp "${path}.pi-setup.XXXXXX")
	cat > "$CURRENT_TEMP"
	chmod "$mode" "$CURRENT_TEMP"
	chown root:root "$CURRENT_TEMP"
	if [[ -f $path ]] && cmp -s "$CURRENT_TEMP" "$path" &&
		[[ $(stat -c '%a:%u:%g' "$path") == "${mode#0}:0:0" ]]; then
		rm -f -- "$CURRENT_TEMP"; CURRENT_TEMP=""
		status ok "$path"
		return
	fi
	backup_file "$path"
	mv -f -- "$CURRENT_TEMP" "$path"; CURRENT_TEMP=""
	FILE_CHANGED=1
	status changed "$path"
}

apt_run() {
	local start=$SECONDS rc
	while :; do
		if DEBIAN_FRONTEND=noninteractive apt-get -y \
			-o "DPkg::Lock::Timeout=$WAIT_TIMEOUT" -o Acquire::Retries=3 \
			-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
			"$@" </dev/null 2>&1 | tee "$RUN_DIR/apt-output"; then
			return 0
		else rc=$?; fi
		if grep -Eq 'Could not get lock|Unable to acquire.*lock' "$RUN_DIR/apt-output" &&
			(( SECONDS - start < WAIT_TIMEOUT )); then
			sleep 5
		else die "apt-get $* failed (exit $rc)"; fi
	done
}

boot_packages() {
	dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null |
		awk '$1 ~ /^(linux-image|raspberrypi-kernel|raspberrypi-bootloader|raspi-firmware|rpi-eeprom)/' | sort
}

install_packages() {
	local packages=(ca-certificates curl gnupg alsa-utils iw avahi-daemon avahi-utils)
	boot_packages > "$RUN_DIR/boot-packages.before"
	# rpi-eeprom's package hooks can flash firmware. Keep that package unchanged
	# during ordinary upgrades; restore the original hold state on every exit.
	if (( ! EEPROM )) && [[ $(dpkg-query -W -f='${db:Status-Status}' rpi-eeprom 2>/dev/null) == installed ]] &&
		! apt-mark showhold | grep -qx rpi-eeprom; then
		EEPROM_HELD=1
		apt-mark hold rpi-eeprom
	fi
	apt_run update
	if (( UPGRADE )); then apt_run full-upgrade; else status skipped 'full system upgrade'; fi
	(( FIREWALL == 0 )) || packages+=(nftables)
	(( UNATTENDED == 0 )) || packages+=(unattended-upgrades)
	(( WATCHDOG == 0 )) || packages+=(psmisc)
	apt_run install "${packages[@]}"
	detect_reboot
	status ok 'system packages installed'
}

install_raspotify() {
	local key="$RUN_DIR/raspotify-key.asc" fingerprints
	install -d -m 0700 "$RUN_DIR/gnupg"
	curl -fsSL --connect-timeout 10 --max-time 60 "$REPO_URL/key.asc" -o "$key"
	fingerprints=$(gpg --homedir "$RUN_DIR/gnupg" --batch --no-options --with-colons --show-keys "$key" |
		awk -F: '$1 == "pub" {primary=1; next} primary && $1 == "fpr" {print $10; primary=0}')
	[[ $fingerprints == "$REPO_FINGERPRINT" ]] || die 'Raspotify repository signing key does not match the reviewed fingerprint'
	# Recognize the official installer's legacy source, but refuse other duplicates.
	local source
	while IFS= read -r source; do
		case $source in
			/etc/apt/sources.list.d/raspotify.list|/etc/apt/sources.list.d/pi-setup-raspotify.sources) ;;
			*) die "Raspotify is already configured in $source; consolidate that source before continuing" ;;
		esac
	done < <(grep -l '^[^#]*dtcooper.github.io/raspotify' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true)
	if [[ -f /etc/apt/sources.list.d/raspotify.list ]]; then
		if grep -Ev '^[[:space:]]*(#.*)?$|^deb \[signed-by=/usr/share/keyrings/raspotify_key.asc\] https://dtcooper.github.io/raspotify/? raspotify main[[:space:]]*$' /etc/apt/sources.list.d/raspotify.list >/dev/null; then
			die 'raspotify.list contains custom sources; consolidate it before continuing'
		fi
		backup_file /etc/apt/sources.list.d/raspotify.list
		rm /etc/apt/sources.list.d/raspotify.list
	fi
	write_file /etc/apt/keyrings/raspotify.asc 0644 < "$key"
	write_file /etc/apt/sources.list.d/pi-setup-raspotify.sources 0644 <<EOF
Types: deb
URIs: $REPO_URL
Suites: raspotify
Components: main
Signed-By: /etc/apt/keyrings/raspotify.asc
EOF
	apt_run update
	apt_run install raspotify
	dpkg-query -W -f='Raspotify ${Version}\n' raspotify
	librespot --version
	librespot --help > "$RUN_DIR/librespot-help"
	local option
	for option in name bitrate backend device format dither mixer initial-volume volume-ctrl \
		volume-range enable-volume-normalisation device-type zeroconf-port zeroconf-backend \
		disable-audio-cache system-cache; do
		grep -Eq -- "(^|[[:space:]])--${option}([[:space:]=,<]|$)" "$RUN_DIR/librespot-help" ||
			die "installed librespot does not advertise --$option"
	done
	local listener
	listener=$(ss -H -lntp "sport = :$ZEROCONF_PORT")
	[[ -z $listener || $listener == *'"librespot"'* ]] || die "TCP $ZEROCONF_PORT is already occupied by another process"
	[[ $(findmnt -n -o FSTYPE -T /run) == tmpfs ]] || die '/run is not tmpfs; cannot guarantee RAM-backed audio buffering'
	systemctl show raspotify.service -p Environment --value |
		grep -Eq '(^|[[:space:]])TMPDIR=/run/raspotify([[:space:]]|$)' ||
		die 'the installed Raspotify unit does not provide the expected RAM-backed TMPDIR'
	status ok 'Raspotify options and runtime buffering configuration verified'
}

audio_signature() {
	{
		printf '%s\n' "$ALSA_DEVICE"
		uname -r
		aplay --version
		cat "$ALSA_CARD_DIR/id"
		# Exclude subdevices_avail and running-stream fields: they change during playback.
		grep -hE '^(card|device|id|name|stream|subdevices_count):' "$ALSA_CARD_DIR"/pcm*p/info
		grep -hE '^[[:space:]]*(Interface [0-9]+|Altset [0-9]+|Format:|Channels:|Rates:|Endpoint:)' "$ALSA_CARD_DIR"/stream* 2>/dev/null || true
	} | sha256sum | awk '{print $1}'
}

probe_audio() {
	local signature cached_signature="" cached_format="" format
	signature=$(audio_signature)
	if [[ -r $STATE_DIR/audio-probe ]]; then
		read -r cached_signature cached_format < "$STATE_DIR/audio-probe" || true
		if [[ $cached_signature == "$signature" ]]; then
			case $cached_format in
				S24|S24_3|S16) AUDIO_FORMAT=$cached_format; status ok "cached 44.1 kHz stereo probe: $AUDIO_FORMAT"; return ;;
			esac
		fi
	fi
	if systemctl is-active --quiet raspotify.service; then
		PROBE_STOPPED=1
		systemctl stop raspotify.service
	fi
	for format in S24_LE S24_3LE S16_LE; do
		if timeout 8 aplay -D "$ALSA_DEVICE" -t raw -c 2 -r 44100 -f "$format" \
			-d 1 --disable-resample --dump-hw-params -v /dev/zero > "$RUN_DIR/audio-probe" 2>&1 &&
			! grep -qi 'rate is not accurate' "$RUN_DIR/audio-probe" &&
			grep -Eq '^[[:space:]]*rate[[:space:]]*:[[:space:]]*44100([[:space:]]|$)' "$RUN_DIR/audio-probe"; then
			case $format in S24_LE) AUDIO_FORMAT=S24 ;; S24_3LE) AUDIO_FORMAT=S24_3 ;; S16_LE) AUDIO_FORMAT=S16 ;; esac
			printf '%s %s\n' "$signature" "$AUDIO_FORMAT" > "$STATE_DIR/audio-probe"
			status ok "verified 44.1 kHz stereo playback: $format ($AUDIO_FORMAT)"
			return
		fi
		status skipped "direct 44.1 kHz stereo probe failed for $format"
		cat "$RUN_DIR/audio-probe"
	done
	die 'DAC could not play 44.1 kHz stereo directly; check device access and capabilities before configuring resampling'
}

environment_value() {
	local value=$1
	value=${value//\\/\\\\}
	value=${value//\"/\\\"}
	printf '"%s"' "$value"
}

render_raspotify_config() {
	local input=$1
	# EnvironmentFile is not a shell script: do not source it or emit export.
	awk '
		/^# BEGIN pi-setup$/ {managed=1; next}
		/^# END pi-setup$/ {managed=0; next}
		managed {next}
		/^[[:space:]]*(LIBRESPOT_(NAME|BITRATE|BACKEND|DEVICE|FORMAT|DITHER|MIXER|INITIAL_VOLUME|VOLUME_CTRL|VOLUME_RANGE|ENABLE_VOLUME_NORMALISATION|DEVICE_TYPE|AUTOPLAY|QUIET|VERBOSE|ZEROCONF_PORT|ZEROCONF_BACKEND|DISABLE_DISCOVERY|DISABLE_AUDIO_CACHE|DISABLE_CREDENTIAL_CACHE|SYSTEM_CACHE)|TMPDIR)[[:space:]]*=/ {next}
		{print}
	' "$input"
	printf '# BEGIN pi-setup\nLIBRESPOT_NAME='
	environment_value "$NAME"
	cat <<EOF

LIBRESPOT_BITRATE=320
LIBRESPOT_BACKEND=alsa
LIBRESPOT_DEVICE=$ALSA_DEVICE
LIBRESPOT_FORMAT=$AUDIO_FORMAT
LIBRESPOT_DITHER=tpdf
LIBRESPOT_MIXER=softvol
LIBRESPOT_INITIAL_VOLUME=50
LIBRESPOT_VOLUME_CTRL=log
LIBRESPOT_VOLUME_RANGE=60
LIBRESPOT_ENABLE_VOLUME_NORMALISATION=
LIBRESPOT_DEVICE_TYPE=speaker
LIBRESPOT_ZEROCONF_PORT=$ZEROCONF_PORT
LIBRESPOT_ZEROCONF_BACKEND=avahi
LIBRESPOT_DISABLE_AUDIO_CACHE=
LIBRESPOT_SYSTEM_CACHE=/var/lib/raspotify
# Credential caching/discovery are enabled by omitting their disabling flags.
# Autoplay follows the client. TMPDIR comes from the packaged systemd unit.
# END pi-setup
EOF
}

configure_raspotify() {
	local changed
	render_raspotify_config /etc/raspotify/conf > "$RUN_DIR/raspotify.conf"
	write_file /etc/raspotify/conf 0600 < "$RUN_DIR/raspotify.conf"
	changed=$FILE_CHANGED
	systemctl enable --now avahi-daemon.service
	systemctl enable raspotify.service
	if (( changed )) || ! systemctl is-active --quiet raspotify.service; then
		systemctl restart raspotify.service
		status changed 'Raspotify started with the managed configuration'
	fi
	PROBE_STOPPED=0
	verify_raspotify
}

verify_raspotify() {
	local attempt
	for (( attempt=0; attempt<5; attempt++ )); do
		sleep 2
		if ! systemctl is-active --quiet raspotify.service; then
			journalctl -u raspotify.service -n 60 --no-pager || true
			die 'Raspotify did not remain active'
		fi
	done
	ss -H -lntp "sport = :$ZEROCONF_PORT" | grep -q '"librespot"' || die 'librespot is not listening on the configured discovery TCP port'
	journalctl -u raspotify.service --since '-2 minutes' -n 40 --no-pager || true
	status ok 'Raspotify is healthy and listening; audible playback is not yet verified'
	if have avahi-browse; then
		timeout 8 avahi-browse -rt _spotify-connect._tcp || true
	fi
}

configure_wifi() {
	(( WIFI_FIX )) || { status skipped 'Wi-Fi power-save management'; return; }
	have nmcli || { warn 'NetworkManager is unavailable; Wi-Fi power saving was not managed'; return; }
	local uuid type current interface
	while IFS=: read -r uuid type; do
		[[ $type == 802-11-wireless ]] || continue
		current=$(nmcli -g 802-11-wireless.powersave connection show uuid "$uuid")
		if [[ $current != 2* ]]; then
			printf '%s\n' "$current" > "$BACKUP_DIR/wifi-$uuid.powersave"
			nmcli connection modify uuid "$uuid" 802-11-wireless.powersave 2
			status changed "Wi-Fi profile $uuid: power saving disabled"
		else status ok "Wi-Fi profile $uuid: power saving already disabled"; fi
	done < <(nmcli -t -f UUID,TYPE connection show)
	# iw changes only runtime power saving; no profile reactivation or link drop.
	while IFS= read -r interface; do
		[[ -n $interface ]] || continue
		if iw dev "$interface" get power_save | grep -q ': on'; then
			if iw dev "$interface" set power_save off; then status changed "$interface: runtime power saving disabled";
			else warn "$interface: live power-save change failed; persisted profile will apply on reconnect"; fi
		fi
	done < <(iw dev | awk '$1 == "Interface" {print $2}')
}

configure_updates() {
	(( UNATTENDED )) || { status skipped 'automatic-update management'; return; }
	local unit schedule changed
	write_file /etc/apt/apt.conf.d/99-pi-setup 0644 <<'EOF'
APT::Periodic::Enable "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "false";
// EEPROM flashing remains an explicit bootstrap --update-eeprom operation.
Unattended-Upgrade::Package-Blacklist { "^rpi-eeprom$"; };
// Debian security plus the stable Raspberry Pi OS archives. Raspberry Pi and
// Raspbian do not publish a separate security-only origin. No third-party apps.
#clear Unattended-Upgrade::Allowed-Origins;
#clear Unattended-Upgrade::Origins-Pattern;
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
    "origin=Raspbian,codename=${distro_codename},label=Raspbian,component=main";
    "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation,component=main";
};
EOF
	for unit in apt-daily apt-daily-upgrade; do
		if [[ $unit == apt-daily ]]; then schedule=04:00:00; else schedule=04:30:00; fi
		write_file "/etc/systemd/system/$unit.timer.d/pi-setup.conf" 0644 <<EOF
[Timer]
OnCalendar=
OnCalendar=*-*-* $schedule
RandomizedDelaySec=0
AccuracySec=1min
Persistent=false
EOF
		changed=$FILE_CHANGED
		systemctl daemon-reload
		systemctl enable "$unit.timer"
		if (( changed )); then systemctl restart "$unit.timer"; else systemctl start "$unit.timer"; fi
	done
	apt-config dump | grep -E 'APT::Periodic|Unattended-Upgrade::(Automatic-Reboot|Origins-Pattern)' || true
	systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager
	status ok "APT scheduled at 04:00/04:30 in $(timedatectl show -p Timezone --value); missed runs do not catch up"
	warn 'off-hours scheduling cannot guarantee that updates never overlap playback'
}

unit_exists() { [[ $(systemctl show "$1" -p LoadState --value 2>/dev/null) == loaded ]]; }

disable_unit() {
	local unit=$1
	unit_exists "$unit" || { status skipped "$unit is not installed"; return; }
	if systemctl is-enabled --quiet "$unit" || systemctl is-active --quiet "$unit"; then
		systemctl disable --now "$unit"
		DISABLED_SERVICES+=" $unit"
		status changed "disabled $unit"
	else status ok "$unit is already disabled/inactive"; fi
}

disable_unused_services() {
	local controllers
	controllers=$(find /sys/class/bluetooth -maxdepth 1 -name 'hci*' -print 2>/dev/null) || controllers=""
	if [[ -z $controllers ]] && grep -Eq '^[[:space:]]*dtoverlay=disable-bt([,[:space:]-]|$)' /boot/firmware/config.txt; then
		disable_unit bluetooth.service
		disable_unit hciuart.service
	else status skipped 'Bluetooth services retained: disabling intent or hardware state is not established'; fi
	if have nmcli && ! nmcli -t -f TYPE connection show --active | grep -Eq '^(gsm|cdma)$'; then
		if have mmcli && mmcli -L 2>/dev/null | grep -q '/Modem/'; then
			status skipped 'ModemManager retained: modem hardware is present'
		else disable_unit ModemManager.service; fi
	else status skipped 'ModemManager retained: cellular usage is active or unverified'; fi
	if ! grep -RsEq '^[[:space:]]*[^#[:space:]]' /etc/triggerhappy/triggers.d 2>/dev/null; then
		disable_unit triggerhappy.service
		disable_unit triggerhappy.socket
	else status skipped 'triggerhappy retained: configured triggers exist'; fi
}

configure_storage() {
	(( VOLATILE_JOURNAL )) || { status skipped 'journald management'; return; }
	write_file /etc/systemd/journald.conf.d/pi-setup.conf 0644 <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
RuntimeKeepFree=32M
RuntimeMaxFileSize=8M
EOF
	if (( FILE_CHANGED )); then systemctl restart systemd-journald.service; fi
	status ok 'journal is volatile (32 MiB cap); bootstrap log is retained separately'
}

configure_watchdog() {
	(( WATCHDOG )) || { status skipped 'hardware watchdog'; return; }
	local device
	device=$(find /dev -maxdepth 1 -type c -name 'watchdog*' -print -quit)
	[[ -n $device ]] || die 'no hardware watchdog device; configure its driver/overlay in the flash setup'
	if systemctl is-active --quiet watchdog.service; then die 'watchdog.service already owns the watchdog'; fi
	for device in /dev/watchdog*; do
		[[ -c $device ]] || continue
		if fuser "$device" >/dev/null 2>&1; then
			# PID 1 may already own it after an earlier run; other owners conflict.
			[[ $(fuser "$device" 2>/dev/null | xargs) == 1 ]] || die "another process owns $device"
		fi
	done
	write_file /etc/systemd/system.conf.d/pi-setup-watchdog.conf 0644 <<'EOF'
[Manager]
RuntimeWatchdogSec=30s
EOF
	if (( FILE_CHANGED )); then REBOOT_NEEDED=1; fi
	status ok 'hardware watchdog configured; activation is deferred to reboot'
}

update_eeprom() {
	if ! have rpi-eeprom-update; then
		if (( EEPROM )); then die 'rpi-eeprom-update is unavailable'; fi
		status skipped 'EEPROM diagnostics unavailable'; return
	fi
	local rc=0
	rpi-eeprom-update </dev/null || rc=$?
	# This tool returns 1 when an update is available.
	if (( rc > 1 )); then
		if (( EEPROM )); then die "EEPROM inspection failed (exit $rc)"; fi
		warn "EEPROM inspection unavailable (exit $rc)"; return
	fi
	if (( EEPROM && rc == 1 )); then
		rpi-eeprom-update -a </dev/null
		REBOOT_NEEDED=1
		status changed 'EEPROM update staged for reboot'
	elif (( rc == 1 )); then status skipped 'EEPROM update available; use --update-eeprom to apply'; fi
}

ssh_service() {
	local unit
	for unit in ssh.service sshd.service; do
		if unit_exists "$unit" && systemctl is-active --quiet "$unit"; then printf '%s\n' "$unit"; return; fi
	done
	return 1
}

ssh_ports() {
	{
		/usr/sbin/sshd -T | awk '$1 == "port" {print $2}'
		ss -H -lntp | awk '/"sshd"/ {port=$4; sub(/^.*:/, "", port); print port}'
		if [[ -n $ORIGINAL_SSH ]]; then printf '%s\n' "$ORIGINAL_SSH" | awk '{print $4}'; fi
	} | awk '/^[0-9]+$/ && $1 > 0 && $1 <= 65535' | sort -nu
}

check_firewall_ownership() {
	local unit tables
	for unit in ufw.service firewalld.service nftables.service netfilter-persistent.service; do
		if unit_exists "$unit" && { systemctl is-active --quiet "$unit" || systemctl is-enabled --quiet "$unit"; }; then
			die "$unit owns the firewall; use --no-firewall or explicitly consolidate firewall management first"
		fi
	done
	tables=$(nft list tables | grep -v '^table inet pi_setup$' || true)
	[[ -z $tables ]] || die "unrelated nftables tables exist; use --no-firewall: $tables"
	local command
	for command in iptables-legacy-save ip6tables-legacy-save; do
		if have "$command" && "$command" 2>/dev/null | grep -q '^-A '; then die 'legacy iptables rules exist; use --no-firewall'; fi
	done
}

render_firewall() {
	local ports=$1 interfaces=$2
	cat <<EOF
table inet pi_setup {
    chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp accept
        ip protocol igmp accept
        meta l4proto ipv6-icmp accept
        udp sport 67 udp dport 68 accept
        udp sport 547 udp dport 546 accept
        tcp dport { $ports } accept
        iifname { $interfaces } udp dport 5353 accept
        iifname { $interfaces } tcp dport $ZEROCONF_PORT accept
    }
}
EOF
}

prepare_access_files() {
	if (( SSH_HARDENING )); then
		cat > "$RUN_DIR/sshd.conf" <<'EOF'
# Managed by bootstrap_raspotify.bash
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
	fi
	if (( FIREWALL )); then
		check_firewall_ownership
		local ports interfaces="" interface
		ports=$(ssh_ports | paste -sd ',' -)
		[[ -n $ports ]] || die 'could not determine SSH ports for the firewall'
		# Only physical LAN interfaces; do not advertise on loopback, VPNs or bridges.
		for interface in /sys/class/net/*; do
			[[ -e $interface/device ]] || continue
			interface=${interface##*/}
			[[ $interface =~ ^[[:alnum:]_.:-]+$ ]] || die 'unsupported network-interface name'
			interfaces+="${interfaces:+, }\"$interface\""
		done
		[[ -n $interfaces ]] || die 'no physical LAN interface found for discovery rules'
		render_firewall "$ports" "$interfaces" > "$RUN_DIR/firewall.nft"
		cat > "$RUN_DIR/firewall-helper" <<'EOF'
#!/bin/bash
set -euo pipefail
rules=$(mktemp /run/pi-setup-firewall.XXXXXX)
trap 'rm -f "$rules"' EXIT
if /usr/sbin/nft list table inet pi_setup >/dev/null 2>&1; then
    printf 'delete table inet pi_setup\n' > "$rules"
fi
cat /etc/pi-setup/firewall.nft >> "$rules"
/usr/sbin/nft -c -f "$rules"
/usr/sbin/nft -f "$rules"
EOF
		cat > "$RUN_DIR/firewall.service" <<'EOF'
[Unit]
Description=Pi audio appliance firewall
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target
Wants=network-pre.target
[Service]
Type=oneshot
ExecStart=/usr/local/libexec/pi-setup-firewall
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
	fi
}

access_paths() {
	(( SSH_HARDENING == 0 )) || printf '%s\n' /etc/ssh/sshd_config.d/00-pi-setup.conf
	if (( FIREWALL )); then
		printf '%s\n' /etc/pi-setup/firewall.nft /usr/local/libexec/pi-setup-firewall /etc/systemd/system/pi-setup-firewall.service
	fi
}

serialize_program() {
	local entry=$1 variable
	printf '#!/bin/bash\nset -Eeuo pipefail\nexport PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C\numask 077\n'
	declare -f
	for variable in NAME USB_AUDIO_CARD_ID ZEROCONF_PORT WAIT_TIMEOUT DRY_RUN UPGRADE FIREWALL SSH_HARDENING \
		UNATTENDED WIFI_FIX VOLATILE_JOURNAL WATCHDOG EEPROM REBOOT LOG STATE_DIR \
		ACCESS_DIR ACCESS_LOCK REPO_URL REPO_FINGERPRINT RUN_DIR RUN_ID BACKUP_DIR LOGIN_USER ORIGINAL_SSH \
		ALSA_DEVICE ALSA_CARD ALSA_CARD_DIR AUDIO_FORMAT REBOOT_NEEDED FILE_CHANGED PROBE_STOPPED WARNINGS EEPROM_HELD \
		DISABLED_SERVICES CURRENT_TEMP SSH_UNIT; do
		printf '%s=%q\n' "$variable" "${!variable}"
	done
	printf '%s\n' "$entry"
}

access_rollback() {
	exec 8>"$ACCESS_LOCK"
	flock 8
	[[ -r $ACCESS_DIR/status && $(cat "$ACCESS_DIR/status") == pending ]] || return 0
	local path failed=0
	status warning 'restoring previous SSH/firewall configuration'
	if (( FIREWALL )); then
		# Disable before removing a newly created unit file, so its enablement
		# symlinks can still be resolved. This service has no destructive ExecStop.
		systemctl stop pi-setup-firewall.service 2>/dev/null || true
		systemctl disable pi-setup-firewall.service 2>/dev/null || true
	fi
	while IFS= read -r path; do
		if [[ -f $ACCESS_DIR/files$path ]]; then
			cp -a -- "$ACCESS_DIR/files$path" "$path" || failed=1
		else rm -f -- "$path" || failed=1; fi
	done < "$ACCESS_DIR/paths"
	systemctl daemon-reload || failed=1
	# Attempt SSH recovery even if firewall service recovery encounters an error.
	if (( SSH_HARDENING )); then
		if /usr/sbin/sshd -t; then systemctl reload "$SSH_UNIT" || failed=1; else failed=1; fi
	fi
	if (( FIREWALL )); then
		if [[ $(cat "$ACCESS_DIR/firewall-enabled") == enabled ]]; then
			systemctl enable pi-setup-firewall.service || failed=1
		fi
		if [[ $(cat "$ACCESS_DIR/firewall-active") == active ]]; then
			systemctl start pi-setup-firewall.service || failed=1
		fi
		# Restore the actual previous rules AFTER any service reload, because the
		# previous runtime rules may have differed from its on-disk configuration.
		: > "$ACCESS_DIR/restore.nft"
		if nft list table inet pi_setup >/dev/null 2>&1; then
			printf 'delete table inet pi_setup\n' >> "$ACCESS_DIR/restore.nft"
		fi
		cat "$ACCESS_DIR/table.nft" >> "$ACCESS_DIR/restore.nft"
		if [[ -s $ACCESS_DIR/restore.nft ]]; then
			if nft -c -f "$ACCESS_DIR/restore.nft"; then nft -f "$ACCESS_DIR/restore.nft" || failed=1; else failed=1; fi
		fi
	fi
	if (( failed )); then
		status failed "rollback incomplete; snapshots and recovery command retained at $ACCESS_DIR/rollback"
		return 1
	fi
	printf 'rolled-back\n' > "$ACCESS_DIR/status"
	status changed 'access configuration rolled back; rerun after resolving the failed verification'
}

access_confirm() {
	(( EUID == 0 )) || die 'run this confirmation with sudo from a new SSH connection'
	local connection
	connection=$(ssh_connection)
	[[ -n $connection && $connection != "$ORIGINAL_SSH" ]] ||
		die 'confirmation requires a new SSH transport; reconnect with ssh -o ControlMaster=no -o ControlPath=none'
	exec 8>"$ACCESS_LOCK"
	flock 8
	[[ -r $ACCESS_DIR/status && $(cat "$ACCESS_DIR/status") == pending ]] || die 'no pending access transaction'
	# Stop a rollback that may be waiting for the lock before committing.
	systemctl stop pi-setup-access-rollback.timer pi-setup-access-rollback.service
	printf 'confirmed\n' > "$ACCESS_DIR/status"
	status ok 'fresh SSH access and sudo confirmed; rollback cancelled'
}

verify_ssh_policy() {
	local client _client_port server server_port host
	local context=()
	if [[ -n $ORIGINAL_SSH ]]; then
		read -r client _client_port server server_port <<< "$ORIGINAL_SSH"
		host=$(getent hosts "$client" | awk 'NR == 1 {print $2}') || host=$client
		context=(-C "user=$LOGIN_USER,host=${host:-$client},addr=$client,laddr=$server,lport=$server_port")
	fi
	/usr/sbin/sshd -t
	/usr/sbin/sshd -T "${context[@]}" > "$RUN_DIR/sshd-effective"
	local setting
	for setting in 'passwordauthentication no' 'kbdinteractiveauthentication no' 'permitrootlogin no' 'pubkeyauthentication yes'; do
		grep -qx "$setting" "$RUN_DIR/sshd-effective" || die "SSH policy overridden by existing configuration: $setting"
	done
	if [[ -n $ORIGINAL_SSH ]]; then
		/usr/sbin/sshd -T -C "user=root,host=${host:-$client},addr=$client,laddr=$server,lport=$server_port" > "$RUN_DIR/sshd-root"
		grep -qx 'permitrootlogin no' "$RUN_DIR/sshd-root" || die 'a Match block still permits root SSH login'
	fi
}

apply_access() {
	if (( ! FIREWALL && ! SSH_HARDENING )); then status skipped 'SSH and firewall management'; return; fi
	SSH_UNIT=$(ssh_service) || die 'no active SSH service found'
	prepare_access_files
	local changed=0 path source
	while IFS= read -r path; do
		case $path in
			*/00-pi-setup.conf) source=$RUN_DIR/sshd.conf ;;
			*/firewall.nft) source=$RUN_DIR/firewall.nft ;;
			*/pi-setup-firewall) source=$RUN_DIR/firewall-helper ;;
			*/pi-setup-firewall.service) source=$RUN_DIR/firewall.service ;;
		esac
		[[ -f $path ]] && cmp -s "$source" "$path" || changed=1
	done < <(access_paths)
	if (( FIREWALL )); then
		nft list table inet pi_setup >/dev/null 2>&1 || changed=1
		systemctl is-enabled --quiet pi-setup-firewall.service || changed=1
		systemctl is-active --quiet pi-setup-firewall.service || changed=1
	fi
	# Reconcile runtime drift as well as disk contents.
	if (( changed == 0 && FIREWALL )); then
		nft -s list table inet pi_setup > "$RUN_DIR/firewall-current"
		[[ -r $STATE_DIR/firewall-effective ]] && cmp -s "$RUN_DIR/firewall-current" "$STATE_DIR/firewall-effective" || changed=1
	fi
	if (( changed == 0 )); then
		(( SSH_HARDENING == 0 )) || verify_ssh_policy
		status ok 'access configuration already matches; no reload or rollback needed'
		return
	fi
	exec 8>"$ACCESS_LOCK"
	flock 8
	secure_directory "$ACCESS_DIR"
	access_paths > "$ACCESS_DIR/paths"
	while IFS= read -r path; do
		[[ ! -L $path ]] || die "refusing access configuration symlink: $path"
		if [[ -e $path ]]; then
			install -d -m 0700 "$(dirname "$ACCESS_DIR/files$path")"
			cp -a -- "$path" "$ACCESS_DIR/files$path"
		fi
	done < "$ACCESS_DIR/paths"
	if (( FIREWALL )); then
		nft list table inet pi_setup > "$ACCESS_DIR/table.nft" 2>/dev/null || : > "$ACCESS_DIR/table.nft"
		systemctl is-enabled pi-setup-firewall.service > "$ACCESS_DIR/firewall-enabled" 2>/dev/null || true
		systemctl is-active pi-setup-firewall.service > "$ACCESS_DIR/firewall-active" 2>/dev/null || true
	fi
	serialize_program access_rollback > "$ACCESS_DIR/rollback"
	serialize_program access_confirm > "$ACCESS_DIR/confirm"
	chmod 0700 "$ACCESS_DIR/rollback" "$ACCESS_DIR/confirm"
	printf 'pending\n' > "$ACCESS_DIR/status"
	systemctl stop pi-setup-access-rollback.timer pi-setup-access-rollback.service 2>/dev/null || true
	systemctl reset-failed pi-setup-access-rollback.service 2>/dev/null || true
	systemd-run --unit=pi-setup-access-rollback --on-active=10m --timer-property=AccuracySec=1s \
		--property="StandardOutput=append:$LOG" --property=StandardError=inherit "$ACCESS_DIR/rollback"
	if (( SSH_HARDENING )); then
		write_file /etc/ssh/sshd_config.d/00-pi-setup.conf 0644 < "$RUN_DIR/sshd.conf"
		verify_ssh_policy
		systemctl reload "$SSH_UNIT"
	fi
	if (( FIREWALL )); then
		write_file /etc/pi-setup/firewall.nft 0644 < "$RUN_DIR/firewall.nft"
		write_file /usr/local/libexec/pi-setup-firewall 0755 < "$RUN_DIR/firewall-helper"
		write_file /etc/systemd/system/pi-setup-firewall.service 0644 < "$RUN_DIR/firewall.service"
		systemctl daemon-reload
		systemctl enable pi-setup-firewall.service
		systemctl restart pi-setup-firewall.service
	fi
	flock -u 8
	exec 8>&-
	status warning 'ACCESS CONFIRMATION REQUIRED within ten minutes, from a NEW SSH connection:'
	local connect_host connect_port
	if [[ -n $ORIGINAL_SSH ]]; then
		connect_host=$(awk '{print $3}' <<< "$ORIGINAL_SSH")
		connect_port=$(awk '{print $4}' <<< "$ORIGINAL_SSH")
	else
		connect_host=$(hostname -I | awk '{print $1}')
		connect_port=$(ssh_ports | sed -n '1p')
	fi
	printf '  ssh -o ControlMaster=no -o ControlPath=none -p %s %s@%s\n' "$connect_port" "$LOGIN_USER" "$connect_host"
	printf '  sudo %s/confirm\n' "$ACCESS_DIR"
	local started=$SECONDS result
	while (( SECONDS - started < 620 )); do
		result=$(cat "$ACCESS_DIR/status")
		case $result in
			confirmed)
				if (( FIREWALL )); then nft -s list table inet pi_setup > "$STATE_DIR/firewall-effective"; fi
				status ok 'access changes confirmed'; return ;;
			rolled-back) die 'access confirmation expired; changes were rolled back' ;;
		esac
		sleep 2
	done
	die 'access confirmation timed out; rollback remains armed'
}

postboot_verify() {
	local rc=0 expected_device=$ALSA_DEVICE
	RUN_DIR=$(mktemp -d /run/pi-setup-verify.XXXXXXXX)
	trap 'rc=$?; printf "postboot %s exit=%s\n" "$(date -Is)" "$rc" >> "$STATE_DIR/last-run";
		systemctl disable pi-setup-verify.service >/dev/null 2>&1 || true;
		rm -f /etc/systemd/system/pi-setup-verify.service /usr/local/libexec/pi-setup-verify;
		rm -rf "$RUN_DIR"; trim_log; systemctl daemon-reload; exit "$rc"' EXIT
	[[ $(cat /proc/sys/kernel/random/boot_id) != "$(cat "$STATE_DIR/pre-reboot-boot-id")" ]] || die 'boot ID did not change'
	rm -f "$STATE_DIR/reboot-needed"
	local started=$SECONDS
	until systemctl is-active --quiet raspotify.service; do
		(( SECONDS - started < WAIT_TIMEOUT )) || die 'Raspotify did not become ready after reboot'
		sleep 2
	done
	select_audio
	[[ $ALSA_DEVICE == "$expected_device" ]] || die 'the selected playback device changed after reboot'
	verify_raspotify
	if (( FIREWALL )); then
		systemctl is-active --quiet pi-setup-firewall.service || die 'firewall service failed after reboot'
		nft -s list table inet pi_setup > "$STATE_DIR/firewall-postboot"
		cmp -s "$STATE_DIR/firewall-postboot" "$STATE_DIR/firewall-effective" || die 'firewall rules changed after reboot'
	fi
	if (( SSH_HARDENING )); then verify_ssh_policy; fi
	if (( WATCHDOG )); then
		[[ $(systemctl show -p RuntimeWatchdogUSec --value) != 0 ]] || die 'hardware watchdog is not active after reboot'
	fi
	report_hardware
	status ok 'post-boot verification passed; audible playback still requires a Spotify session'
}

detect_reboot() {
	local boot_id
	boot_id=$(cat /proc/sys/kernel/random/boot_id)
	if [[ -e /var/run/reboot-required || -e /run/rpi-eeprom-update-pending ]]; then REBOOT_NEEDED=1; fi
	if [[ -r $STATE_DIR/reboot-needed && $(cat "$STATE_DIR/reboot-needed") == "$boot_id" ]]; then REBOOT_NEEDED=1; fi
	if [[ -r $RUN_DIR/boot-packages.before ]]; then
		boot_packages > "$RUN_DIR/boot-packages.after"
		if ! cmp -s "$RUN_DIR/boot-packages.before" "$RUN_DIR/boot-packages.after"; then REBOOT_NEEDED=1; fi
	fi
	if (( REBOOT_NEEDED )); then printf '%s\n' "$boot_id" > "$STATE_DIR/reboot-needed"; fi
}

prepare_reboot() {
	detect_reboot
	if (( REBOOT_NEEDED == 0 )); then
		status ok 'no reboot requirement detected (the OS may not flag every firmware change)'; return
	fi
	status warning 'reboot required'
	cat /proc/sys/kernel/random/boot_id > "$STATE_DIR/pre-reboot-boot-id"
	serialize_program postboot_verify > "$RUN_DIR/postboot"
	write_file /usr/local/libexec/pi-setup-verify 0700 < "$RUN_DIR/postboot"
	write_file /etc/systemd/system/pi-setup-verify.service 0644 <<EOF
[Unit]
Description=Verify Pi audio setup after reboot
After=network-online.target raspotify.service pi-setup-firewall.service
Wants=network-online.target raspotify.service
[Service]
Type=oneshot
ExecStart=/usr/local/libexec/pi-setup-verify
TimeoutStartSec=$((WAIT_TIMEOUT + 120))
StandardOutput=append:$LOG
StandardError=inherit
[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable pi-setup-verify.service
	if (( REBOOT )); then
		systemd-run --unit="pi-setup-reboot-$RUN_ID" --on-active=20s /usr/bin/systemctl reboot
		status changed 'reboot scheduled in 20 seconds; reconnect to inspect /var/log/pi-setup.log'
	else status skipped 'automatic reboot not requested; run: sudo systemctl reboot'; fi
}

trim_log() {
	# Bound retained history at run boundaries without rotating an open systemd fd.
	local temporary
	[[ -f $LOG ]] || return 0
	if (( $(stat -c %s "$LOG") > 2097152 )); then
		temporary=$(mktemp /var/log/pi-setup-tail.XXXXXX)
		tail -c 1048576 "$LOG" > "$temporary"
		cat "$temporary" > "$LOG"
		rm -f "$temporary"
	fi
}

worker_error() {
	local rc=$1 line=$2
	status failed "run $RUN_ID failed at line $line (exit $rc); see $LOG and $BACKUP_DIR" >&2
	return "$rc"
}

finish_worker() {
	local rc=$1
	trap - EXIT ERR
	set +e
	# Release the apply lock before invoking the independent rollback process.
	flock -u 8 2>/dev/null
	exec 8>&-
	if (( EEPROM_HELD )); then apt-mark unhold rpi-eeprom; fi
	if (( PROBE_STOPPED )); then systemctl start raspotify.service; fi
	if (( rc != 0 )) && [[ -r $ACCESS_DIR/status && $(cat "$ACCESS_DIR/status") == pending ]]; then
		"$ACCESS_DIR/rollback"
	fi
	[[ -z $CURRENT_TEMP ]] || rm -f -- "$CURRENT_TEMP"
	detect_reboot
	printf '%s run=%s exit=%s reboot-needed=%s\n' "$(date -Is)" "$RUN_ID" "$rc" "$REBOOT_NEEDED" > "$STATE_DIR/last-run"
	status "$(if (( rc == 0 )); then printf ok; else printf failed; fi)" "run $RUN_ID finished (exit $rc); log: $LOG"
	trim_log
	# Retain only a tiny result file under /run; remove all executable payloads.
	find "$RUN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
	if [[ -r $ACCESS_DIR/status && $(cat "$ACCESS_DIR/status") != pending ]]; then rm -rf "$ACCESS_DIR"; fi
	printf '%s\n' "$rc" > "$RUN_DIR/result"
	exit "$rc"
}

worker_main() {
	exec 9>/run/pi-setup.lock
	if ! flock -n 9; then
		rm -f "$RUN_DIR/worker"
		printf '1\n' > "$RUN_DIR/result"
		die 'another bootstrap is running'
	fi
	trap 'worker_error "$?" "$LINENO"' ERR
	trap 'finish_worker "$?"' EXIT
	trap 'exit 143' TERM
	secure_directory "$STATE_DIR"
	secure_directory "$BACKUP_DIR"
	status ok "starting run $RUN_ID; backups: $BACKUP_DIR"
	wait_for_cloud_init
	preflight
	report_hardware
	select_audio
	systemctl --failed --plain --no-legend | awk '{print $1}' | sort > "$RUN_DIR/failed.before"
	install_packages
	install_raspotify
	# A package upgrade can replace the kernel-facing ALSA inventory.
	select_audio
	probe_audio
	configure_raspotify
	configure_wifi
	configure_updates
	disable_unused_services
	configure_storage
	configure_watchdog
	update_eeprom
	apt_run autoremove
	apply_access
	verify_raspotify
	systemctl --failed --plain --no-legend | awk '{print $1}' | sort > "$RUN_DIR/failed.after"
	if [[ -n $(comm -13 "$RUN_DIR/failed.before" "$RUN_DIR/failed.after") ]]; then
		warn 'new failed systemd units:'
		comm -13 "$RUN_DIR/failed.before" "$RUN_DIR/failed.after"
	fi
	status ok "Spotify: $NAME; bitrate: 320 kbps; device: $ALSA_DEVICE; format: $AUDIO_FORMAT at 44100 Hz stereo"
	status ok "disabled services:${DISABLED_SERVICES:- none}; warnings: $WARNINGS"
	status ok "addresses: $(hostname -I); credentials cached; audio buffering in RAM"
	status skipped 'audible playback must be verified with a real Spotify session'
	prepare_reboot
}

launch_worker() {
	secure_directory /run/pi-setup
	secure_directory "$STATE_DIR"
	exec 9>/run/pi-setup.lock
	flock -n 9 || die 'another bootstrap is running'
	if [[ -r $ACCESS_DIR/status && $(cat "$ACCESS_DIR/status") == pending ]]; then
		die "access rollback is pending; inspect $ACCESS_DIR/status before starting another run"
	fi
	[[ ! -d $ACCESS_DIR ]] || rm -rf "$ACCESS_DIR"
	RUN_DIR=$(mktemp -d /run/pi-setup/run.XXXXXXXX)
	RUN_ID=${RUN_DIR##*/}
	BACKUP_DIR="/var/backups/pi-setup/$RUN_ID"
	serialize_program worker_main > "$RUN_DIR/worker"
	chmod 0700 "$RUN_DIR/worker"
	[[ ! -L $LOG ]] || die "refusing log symlink: $LOG"
	touch "$LOG"; chmod 0600 "$LOG"; chown root:root "$LOG"
	trim_log
	local start_line tail_pid result
	start_line=$(( $(wc -l < "$LOG") + 1 ))
	# The worker independently acquires the lock. Concurrent launchers cannot both
	# provision: only one worker gets the lock even if launched in this tiny gap.
	flock -u 9
	systemd-run --unit="pi-setup-$RUN_ID" --property=Type=exec \
		--property="StandardOutput=append:$LOG" --property=StandardError=inherit \
		--property=TimeoutStopSec=120 /bin/bash "$RUN_DIR/worker" </dev/null
	status ok "detached service pi-setup-$RUN_ID started; SSH may disconnect without interrupting it"
	tail -n "+$start_line" -F "$LOG" &
	tail_pid=$!
	trap 'kill "$tail_pid" 2>/dev/null || true; printf "Provisioning continues; inspect %s\n" "$LOG"; exit 130' INT TERM HUP
	while [[ ! -r $RUN_DIR/result ]]; do
		if ! systemctl is-active --quiet "pi-setup-$RUN_ID.service"; then
			[[ -r $RUN_DIR/result ]] && break
			kill "$tail_pid" 2>/dev/null || true
			wait "$tail_pid" 2>/dev/null || true
			die "worker stopped without a result; inspect $LOG and systemctl status pi-setup-$RUN_ID"
		fi
		sleep 1
	done
	result=$(cat "$RUN_DIR/result")
	sleep 1
	kill "$tail_pid" 2>/dev/null || true
	wait "$tail_pid" 2>/dev/null || true
	trap - INT TERM HUP
	[[ $result =~ ^[0-9]+$ ]] || die 'invalid worker result'
	exit "$result"
}

main() {
	set -Eeuo pipefail
	export PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C
	umask 077
	defaults
	parse_args "$@"
	check_platform
	LOGIN_USER=${SUDO_USER:-root}
	ORIGINAL_SSH=$(ssh_connection)
	if (( DRY_RUN )); then dry_run; else launch_worker; fi
}

# Sourceable for focused tests; both a downloaded file and bash -s execute main.
if [[ ${BASH_SOURCE[0]:-} == "$0" || -z ${BASH_SOURCE[0]:-} ]]; then
	main "$@"
fi
