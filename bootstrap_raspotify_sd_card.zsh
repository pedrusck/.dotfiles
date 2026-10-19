#!/usr/bin/env zsh
# pi-flash.zsh - Flash Raspberry Pi OS Lite (64-bit, Trixie+) to a microSD on macOS
# for a Raspberry Pi 4 Model B or newer (Pi 4/400/CM4, Pi 5/500/CM5),
# and prepare it offline for a headless, Wi-Fi, key-only SSH first boot.
#
# Usage: pi-flash.zsh <disk> <ssh-key-name> [options]
#   <disk>          e.g. /dev/disk4 or disk4
#   <ssh-key-name>  comment (or SHA256 fingerprint) of a key loaded in ssh-agent
#
# Options:
#   --hostname NAME        default: raspotify
#   --user NAME            default: pi
#   --ssid SSID            Wi-Fi network (omit to skip Wi-Fi)
#   --psk PASSPHRASE       Wi-Fi password (or env PI_WIFI_PSK, or silent prompt)
#   --country CC           Wi-Fi regulatory domain, e.g. GB (required with --ssid)
#   --timezone TZ          default: the Mac's timezone
#   --locale LOCALE        default: en_US.UTF-8
#   --keymap LAYOUT        default: us
#   --keep-bt              do not disable Bluetooth
#   --keep-hdmi            do not disable the HDMI outputs
#   --any-band             do not pin Wi-Fi to the 5 GHz band
#   --keep-leds            do not turn off the activity and power LEDs
#   --performance-governor set CPU governor to performance via cmdline.txt
#   --no-eth-priority      do not add eth0 with a preferred route metric
#   -y, --yes              skip the typed disk confirmation (dangerous)
#
# NOTE: untested skeleton. Verify cloud-init / netplan key names and the
# Pi overlay names against the current Raspberry Pi docs before relying on it.

setopt ERR_EXIT PIPE_FAIL NO_UNSET

IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64_latest"
CACHE_DIR="${HOME}/.cache/pi-flash"

die()  { print -u2 -- "error: $*"; exit 1; }
info() { print -- "==> $*"; }
usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

# ---------- args ----------
(( $# >= 2 )) || usage

DISK_ARG=$1; KEY_NAME=$2; shift 2

HOSTNAME_=raspotify
USER_=pi
SSID=""
PSK="${PI_WIFI_PSK:-}"
COUNTRY=""
TZ_="$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
[[ -n $TZ_ ]] || TZ_=UTC
LOCALE_=en_US.UTF-8
KEYMAP=us
DISABLE_BT=1
DISABLE_HDMI=1
DISABLE_LEDS=1
PIN_5GHZ=1
GOVERNOR=0
ETH_PRIORITY=1
ASSUME_YES=0

while (( $# )); do
	case $1 in
		--hostname) HOSTNAME_=$2; shift 2 ;;
		--user)     USER_=$2; shift 2 ;;
		--ssid)     SSID=$2; shift 2 ;;
		--psk)      PSK=$2; shift 2 ;;
		--country)  COUNTRY=${2:u}; shift 2 ;;
		--timezone) TZ_=$2; shift 2 ;;
		--locale)   LOCALE_=$2; shift 2 ;;
		--keymap)   KEYMAP=$2; shift 2 ;;
		--keep-bt)  DISABLE_BT=0; shift ;;
		--keep-hdmi) DISABLE_HDMI=0; shift ;;
		--keep-leds) DISABLE_LEDS=0; shift ;;
		--any-band) PIN_5GHZ=0; shift ;;
		--performance-governor) GOVERNOR=1; shift ;;
		--no-eth-priority) ETH_PRIORITY=0; shift ;;
		-y|--yes)   ASSUME_YES=1; shift ;;
		-h|--help)  usage 0 ;;
		*) die "unknown option: $1" ;;
	esac
done

# ---------- preflight ----------
[[ $OSTYPE == darwin* ]] || die "macOS only"

for cmd in curl shasum xz dd diskutil plutil ssh-add awk sed; do
	command -v $cmd >/dev/null || die "missing dependency: $cmd$([[ $cmd == xz ]] && print ' (brew install xz)')"
done
HAVE_PV=0; command -v pv >/dev/null && HAVE_PV=1

if [[ -n $SSID ]]; then
	[[ -n $COUNTRY ]] || die "--country is required with --ssid"
	if [[ -z $PSK ]]; then
		read -rs "PSK?Wi-Fi password for '$SSID': "; print
fi
[[ -n $PSK ]] || die "empty Wi-Fi password"
fi

# -- disk validation --
DISK_ID=${DISK_ARG#/dev/}
DISK_ID=${DISK_ID#r}
[[ $DISK_ID == disk<-> ]] || die "disk must look like /dev/disk4"

plist_get() { plutil -extract "$2" raw -o - - <<<"$1" 2>/dev/null || true; }

INFO=$(diskutil info -plist "/dev/$DISK_ID") || die "cannot query /dev/$DISK_ID"
[[ $(plist_get "$INFO" WholeDisk) == true ]] || die "/dev/$DISK_ID is not a whole disk"
[[ $(plist_get "$INFO" VirtualOrPhysical) != Virtual ]] || die "refusing a virtual disk"
[[ $(plist_get "$INFO" RemovableMediaOrExternalDevice) == true ]] \
	|| die "refusing: /dev/$DISK_ID is not removable/external"

BOOT_INFO=$(diskutil info -plist /)
[[ $(plist_get "$BOOT_INFO" ParentWholeDisk) != $DISK_ID ]] || die "refusing: that is the boot disk"

SIZE=$(plist_get "$INFO" TotalSize)
MODEL=$(plist_get "$INFO" MediaName)
(( SIZE >= 8 * 1000 * 1000 * 1000 )) || die "disk smaller than 8 GB"

# -- SSH key from the agent --
ssh-add -l >/dev/null 2>&1 || die "no keys in ssh-agent (is it running?)"
keys=("${(@f)$(ssh-add -L)}")
fps=("${(@f)$(ssh-add -l)}")
PUBKEY=""
for i in {1..${#keys}}; do
	k=(${=keys[i]})   # type, blob, comment...
		f=(${=fps[i]})    # bits, fingerprint, comment..., (type)
		if [[ ${k[3]:-} == $KEY_NAME || ${f[2]} == $KEY_NAME ]]; then
			PUBKEY="${k[1]} ${k[2]}${k[3]:+ ${k[3]}}"
			break
		fi
	done
	[[ -n $PUBKEY ]] || die "key '$KEY_NAME' not found in ssh-agent (see: ssh-add -l)"

# ---------- confirm ----------
print
print -- "Target : /dev/$DISK_ID  ($MODEL, $(( SIZE / 1000000000 )) GB)"
print -- "Key    : ${PUBKEY##* }"
print -- "Host   : $HOSTNAME_   User: $USER_"
print -- "Wi-Fi  : ${SSID:-<none>} ${COUNTRY:+($COUNTRY)}"
print -- "ALL DATA ON /dev/$DISK_ID WILL BE ERASED."
if (( ! ASSUME_YES )); then
	read -r "ANSWER?Type '$DISK_ID' to continue: "
	[[ $ANSWER == $DISK_ID ]] || die "aborted"
fi
sudo -v

# ---------- download ----------
mkdir -p "$CACHE_DIR"
info "Resolving latest image"
FINAL_URL=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$IMAGE_URL")
IMG_NAME=${FINAL_URL:t}
[[ $IMG_NAME == *.img.xz ]] || die "unexpected image name: $IMG_NAME"
if [[ $IMG_NAME == *(bookworm|bullseye|buster)* ]]; then
	die "image is older than Trixie ($IMG_NAME); this script targets cloud-init releases"
fi
IMG="$CACHE_DIR/$IMG_NAME"

if [[ ! -f $IMG ]]; then
	info "Downloading $IMG_NAME"
	curl -fL --progress-bar -o "$IMG.part" "$FINAL_URL"
	mv "$IMG.part" "$IMG"
else
	info "Using cached $IMG_NAME"
fi

info "Verifying SHA-256"
EXPECTED=$(curl -fsSL "$FINAL_URL.sha256" | awk '{print $1}')
[[ -n $EXPECTED ]] || die "could not fetch checksum"
ACTUAL=$(shasum -a 256 "$IMG" | awk '{print $1}')
if [[ $EXPECTED != $ACTUAL ]]; then
	rm -f "$IMG"
	die "checksum mismatch; cached file removed"
fi

# ---------- write ----------
info "Unmounting /dev/$DISK_ID"
diskutil unmountDisk "/dev/$DISK_ID" >/dev/null

info "Writing image (this takes a few minutes)"
if (( HAVE_PV )); then
	xz -dc "$IMG" | pv | sudo dd of="/dev/r$DISK_ID" bs=4m
else
	xz -dc "$IMG" | sudo dd of="/dev/r$DISK_ID" bs=4m
fi
sync

info "Mounting boot partition"
diskutil mountDisk "/dev/$DISK_ID" >/dev/null 2>&1 || true
BOOT=""
for _ in {1..30}; do
	BOOT=$(plist_get "$(diskutil info -plist "/dev/${DISK_ID}s1" 2>/dev/null)" MountPoint)
	[[ -n $BOOT && -d $BOOT ]] && break
	sleep 1
done
[[ -n $BOOT && -f $BOOT/config.txt ]] || die "boot partition did not mount"

# ---------- helpers ----------
yq() { local s=${1//\\/\\\\}; print -r -- "\"${s//\"/\\\"}\""; }   # YAML double-quote

# Replace "key=..." in config.txt if present, else append under [all].
set_cfg() {
	local key=$1 val=$2 f=$BOOT/config.txt
	if grep -q "^${key}=" "$f"; then
		awk -v k="$key" -v v="$val" 'index($0, k"=")==1 {print k"="v; next} {print}' "$f" > "$f.new"
		mv "$f.new" "$f"
	else
		print -r -- "${key}=${val}" >> "$f"
	fi
}

# ---------- user-data ----------
info "Writing user-data"
cat > "$BOOT/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME_
manage_etc_hosts: true
timezone: $TZ_
locale: $LOCALE_
keyboard:
  layout: $KEYMAP

enable_ssh: true
ssh_pwauth: false

users:
  - name: $USER_
	gecos: $USER_
	shell: /bin/bash
	lock_passwd: true
	sudo: ALL=(ALL) NOPASSWD:ALL
	groups: [users, adm, dialout, audio, netdev, video, plugdev, cdrom, games, input, gpio, spi, i2c, render, sudo]
	ssh_authorized_keys:
	  - $PUBKEY
EOF

# ---------- network-config ----------
info "Writing network-config"
{
	print "network:"
	print "  version: 2"
	if (( ETH_PRIORITY )); then
		print "  ethernets:"
		print "    eth0:"
		print "      dhcp4: true"
		print "      optional: true"
		print "      dhcp4-overrides:"
		print "        route-metric: 100"
	fi
	if [[ -n $SSID ]]; then
		print "  wifis:"
		print "    wlan0:"
		print "      dhcp4: true"
		print "      optional: true"
		print "      regulatory-domain: $(yq "$COUNTRY")"
		print "      access-points:"
		print "        $(yq "$SSID"):"
		print "          password: $(yq "$PSK")"
		# Pin to 5 GHz: the Pi never joins if the network offers no 5 GHz radio.
		(( PIN_5GHZ )) && print "          band: 5GHz"
		# Wi-Fi power save off: unverified via netplan passthrough; test, drop if ignored.
		print "      networkmanager:"
		print "        passthrough:"
		print "          wifi.powersave: \"2\""
	fi
} > "$BOOT/network-config"
chmod 600 "$BOOT/network-config" 2>/dev/null || true   # FAT may ignore this

# ---------- config.txt ----------
info "Editing config.txt"
# Onboard (3.5mm / headphone) audio off
awk '
/^dtparam=audio=/ { print "dtparam=audio=off"; seen=1; next }
{ print }
END { if (!seen) print "dtparam=audio=off" }
' "$BOOT/config.txt" > "$BOOT/config.txt.new" && mv "$BOOT/config.txt.new" "$BOOT/config.txt"

# HDMI audio off: append ,noaudio to the vc4-kms-v3d overlay
awk '/^dtoverlay=vc4-kms-v3d/ && !/noaudio/ { $0 = $0 ",noaudio" } { print }' \
	"$BOOT/config.txt" > "$BOOT/config.txt.new" && mv "$BOOT/config.txt.new" "$BOOT/config.txt"

# Skip camera / display auto-detection
set_cfg camera_auto_detect 0
set_cfg display_auto_detect 0

# Activity (green) and power (red) LEDs off. Same dtparams on Pi 4 and Pi 5.
# The firmware may still light the power LED briefly at power-on / on faults.
if (( DISABLE_LEDS )); then
	set_cfg dtparam=act_led_trigger none
	set_cfg dtparam=act_led_activelow off
	set_cfg dtparam=pwr_led_trigger none
	set_cfg dtparam=pwr_led_activelow off
fi

# Bluetooth off (also removes Wi-Fi/BT coexistence interference).
# Pi 4 family and Pi 5 family use different overlays; model filters pick the right one.
# Verify the Pi 5 overlay name (disable-bt-pi5) against your firmware's overlay README.
if (( DISABLE_BT )); then
	cat >> "$BOOT/config.txt" <<'CFG'

# pi-flash: Bluetooth off
[pi4]
dtoverlay=disable-bt
[pi5]
dtoverlay=disable-bt-pi5
[all]
CFG
fi

# ---------- cmdline.txt ----------
info "Editing cmdline.txt"
CMDLINE=$(<"$BOOT/cmdline.txt")
CMDLINE=${CMDLINE%%$'\n'}
add_arg() { [[ " $CMDLINE " == *" $1 "* ]] || CMDLINE+=" $1"; }
add_arg usbcore.autosuspend=-1
(( GOVERNOR )) && add_arg cpufreq.default_governor=performance
# HDMI output off: both connectors on Pi 4 and Pi 5 (KMS driver)
if (( DISABLE_HDMI )); then
	add_arg video=HDMI-A-1:d
	add_arg video=HDMI-A-2:d
fi
print -r -- "$CMDLINE" > "$BOOT/cmdline.txt"

# ---------- finish ----------
sync
info "Ejecting"
diskutil eject "/dev/$DISK_ID" >/dev/null

print
print -- "Done. Insert the card, power on the Pi, wait a few minutes, then:"
print -- "  ssh $USER_@$HOSTNAME_.local"
