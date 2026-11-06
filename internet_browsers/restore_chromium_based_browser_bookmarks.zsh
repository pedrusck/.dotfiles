#!/usr/bin/env zsh
# Replace local Bookmarks in every installed configured Chromium browser.
# No bookmark-content validation. Account/encrypted stores are not replaced.

emulate -LR zsh
setopt errexit nounset pipefail
umask 077
source "${0:A:h}/chromium_browsers.zsh"

function usage() {
	print -r -- "Usage: restore_chromium_based_browser_bookmarks.zsh [OPTIONS] [SOURCE_FILE|SOURCE_DIR]
  --profile BROWSER=DIRECTORY  Override Default profile; repeat for multiple browsers
  --app BROWSER=APP_PATH      Override /Applications or ~/Applications discovery
  -h, --help                  Show help
Browser choices: ${(j:|:)CHROMIUM_BROWSERS}
The source defaults to the script directory. Directories select the newest raw
snapshot by filename timestamp/collision counter. An explicit file selects that
exact copy and may have any name. Relative paths use the current directory.
All installed supported browsers receive the same snapshot. Existing bookmarks
are replaced, not merged, and backed up separately. Only previously running
browsers are relaunched. Missing profiles and per-browser failures are reported;
other browsers are still attempted, and any such failure gives a nonzero exit."
}

function fail() {
	print -ru2 -- "Error: $*"
	return 1
}

# Return an absolute path in REPLY. Directory selection accepts only raw snapshot
# names, with an optional six-digit collision counter, never e.g. *_sorted.*.
function select_snapshot() {
	local source=$1 family=$2 extension=$3 candidate pattern
	local -x LC_ALL=C
	local -a candidates
	REPLY=""
	if [[ -f $source ]]; then
		REPLY=${source:A}
	elif [[ -d $source ]]; then
		pattern="^${family}_based_browser_bookmarks_[0-9]{8}_[0-9]{6}(_[0-9]{6})?\\.secret\\.${extension}$"
		candidates=("$source"/${family}_based_browser_bookmarks_*.secret.${extension}(NOn.))
		for candidate in "${candidates[@]}"; do
			if [[ ${candidate:t} =~ $pattern ]]; then
				REPLY=${candidate:A}
				break
			fi
		done
		[[ -n $REPLY ]] || { fail "no snapshots found in $source"; return 1; }
	else
		fail "source not found: $source"
		return 1
	fi
	[[ -r $REPLY && -s $REPLY ]] || { fail "source is unreadable or empty: $REPLY"; return 1; }
}

# Capture the on-disk file, retrying if it changes during the copy. This does not
# flush pending browser writes or validate the bookmark format.
function copy_snapshot() {
	local source=$1 destination=$2
	local -i attempt
	for attempt in 1 2 3; do
		cp -- "$source" "$destination" || return 1
		if cmp -s -- "$source" "$destination"; then
			return 0
		fi
	done
	fail "source changed during capture or copy verification failed: $source"
}

# Application discovery is independent of leftover browser profile directories.
# Search standard locations; callers can supply an explicit application path.
# Return the absolute application path in REPLY.
function find_chromium_browser_app() {
	local browser=$1 candidate
	local -a candidates=("$HOME/Applications/${CHROMIUM_BROWSER_NAMES[$browser]}.app" "/Applications/${CHROMIUM_BROWSER_NAMES[$browser]}.app")
	REPLY=""
	for candidate in "${candidates[@]}"; do
		if [[ -d $candidate ]]; then
			REPLY=${candidate:A}
			return 0
		fi
	done
	return 1
}

SOURCE=${0:A:h}
typeset -i SOURCE_SET=0
typeset -A PROFILES APPS
while (( $# )); do
	case $1 in
		-h|--help) usage; exit 0 ;;
		--profile|--app)
			(( $# >= 2 )) || { fail "missing value for $1"; exit 1; }
			KEY=${2%%=*} VALUE=${2#*=}
			[[ $2 == *=* && -n $VALUE && ${CHROMIUM_BROWSERS[(Ie)$KEY]} -gt 0 ]] || { fail "expected ${(j:|:)CHROMIUM_BROWSERS}=PATH for $1"; exit 1; }
			if [[ $1 == --profile ]]; then PROFILES[$KEY]=${VALUE:A}; else APPS[$KEY]=${VALUE:A}; fi
			shift 2 ;;
		--)
			shift
			(( $# == 1 && ! SOURCE_SET )) || { fail 'expected one source after --'; exit 1; }
			SOURCE=$1 SOURCE_SET=1
			shift ;;
		-*) fail "unknown option: $1"; exit 1 ;;
		*)
			(( ! SOURCE_SET )) || { fail "unexpected argument: $1"; exit 1; }
			SOURCE=$1 SOURCE_SET=1
			shift ;;
	esac
done
select_snapshot "$SOURCE" chromium json
SOURCE_FILE=$REPLY

# Freeze the source once so every browser receives identical bytes, including
# when the explicit source is itself one of the live destination files.
CAPTURE_DIR=""
function cleanup_capture() {
	local -i result=$? failed=0
	[[ -z $CAPTURE_DIR ]] || rm -rf -- "$CAPTURE_DIR" || failed=1
	trap - EXIT
	exit $(( result ? result : failed ))
}
trap cleanup_capture EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
CAPTURE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bookmarks-restore.XXXXXXXX")
copy_snapshot "$SOURCE_FILE" "$CAPTURE_DIR/Bookmarks"
print -r -- "Snapshot: $SOURCE_FILE"

# Each browser runs in a subshell so its traps/state cannot leak into the next.
# Every fallible operation is checked explicitly: callers aggregate failures.
function restore_browser() (
	local key=$1 app=$2 profile=$3 snapshot=$4
	local name=${CHROMIUM_BROWSER_NAMES[$key]} dest="$profile/Bookmarks"
	local lock="$profile/.bookmarks-restore.lock" temp="" backup="" process_state
	local -i locked=0 was_running=0 waited=0
	function cleanup_browser() {
		local -i result=$? failed=0
		[[ -z $temp ]] || rm -f -- "$temp" || failed=1
		if (( was_running )); then
			# A custom profile outside the browser root needs a user-data-dir too.
			if ! open -a "$app" --args "--user-data-dir=${profile:h}" "--profile-directory=${profile:t}"; then
				print -ru2 -- "$name: relaunch failed."
				failed=1
			fi
		fi
		(( ! locked )) || rmdir -- "$lock" || failed=1
		trap - EXIT
		# Preserve cancellation even if relaunch or cleanup also fails.
		exit $(( result ? result : failed ))
	}
	trap cleanup_browser EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	if [[ ! -d $profile ]]; then
		fail "$name profile not initialized: $profile; launch that profile first"
		return 1
	fi
	# Keep mkdir's diagnostic and only release locks created by this invocation.
	if ! mkdir -- "$lock"; then
		fail "$name could not create restore lock: $lock (see mkdir diagnostic above)"
		return 1
	fi
	locked=1
	print -r -- "$name target: $profile"
	# Process errors are not equivalent to the browser being stopped.
	if pgrep -u "$UID" -x "$name" >/dev/null; then process_state=0; else process_state=$?; fi
	(( process_state <= 1 )) || { fail "$name process detection failed"; return 1; }
	if (( process_state == 0 )); then
		was_running=1
		print -r -- "Quitting $name…"
		osascript - "$app" <<'APPLESCRIPT' >/dev/null || { fail "$name could not quit"; return 1; }
on run argv
	tell application (item 1 of argv) to quit
end run
APPLESCRIPT
		while true; do
			if pgrep -u "$UID" -x "$name" >/dev/null; then process_state=0; else process_state=$?; fi
			(( process_state <= 1 )) || { fail "$name process detection failed"; return 1; }
			(( process_state == 0 )) || break
			(( waited < 10 )) || { fail "$name did not quit in time; bookmarks not replaced"; return 1; }
			sleep 1 || return 1
			(( waited += 1 ))
		done
	fi
	if cmp -s -- "$snapshot" "$dest"; then
		print -r -- "$name: already matching."
		return 0
	fi
	[[ ! -e $dest || -f $dest ]] || { fail "$name destination is not a regular file: $dest"; return 1; }
	if [[ -f $dest ]]; then
		backup=$(mktemp "$dest.before-restore.XXXXXXXX") || return 1
		if ! cp -p -- "$dest" "$backup" || ! cmp -s -- "$dest" "$backup"; then
			rm -f -- "$backup" || true
			fail "$name backup failed; bookmarks not replaced"
			return 1
		fi
		print -r -- "$name previous bookmarks: $backup"
	fi
	temp=$(mktemp "$profile/.Bookmarks.restore.XXXXXXXX") || return 1
	cp -- "$snapshot" "$temp" || return 1
	cmp -s -- "$snapshot" "$temp" || { fail "$name copy verification failed"; return 1; }
	if pgrep -u "$UID" -x "$name" >/dev/null; then process_state=0; else process_state=$?; fi
	(( process_state == 1 )) || { fail "$name is running again or process detection failed; bookmarks not replaced"; return 1; }
	mv -f -- "$temp" "$dest" || return 1
	temp=""
	print -r -- "$name: restored -> $dest"
)

typeset -i FAILED=0 FOUND=0 RESULT=0
typeset -a SUMMARY
for KEY in "${CHROMIUM_BROWSERS[@]}"; do
	NAME=${CHROMIUM_BROWSER_NAMES[$KEY]}
	if [[ -n ${APPS[$KEY]-} ]]; then
		APP=${APPS[$KEY]}
		if [[ ! -d $APP || $APP != *.app ]]; then
			SUMMARY+=("$NAME: failed (application override not found: $APP)")
			FAILED=1
			continue
		fi
	elif find_chromium_browser_app "$KEY"; then
		APP=$REPLY
	else
		SUMMARY+=("$NAME: not installed")
		continue
	fi
	(( FOUND += 1 ))
	PROFILE=${PROFILES[$KEY]:-${CHROMIUM_BROWSER_ROOTS[$KEY]}/Default}
	if restore_browser "$KEY" "$APP" "$PROFILE" "$CAPTURE_DIR/Bookmarks"; then
		SUMMARY+=("$NAME: completed")
	else
		RESULT=$?
		SUMMARY+=("$NAME: failed, see diagnostics above")
		FAILED=1
		# Interrupts cancel the whole operation rather than starting another browser.
		if (( RESULT == 130 || RESULT == 143 )); then exit $RESULT; fi
	fi
done
print -r -- 'Restore summary:'
printf '  %s\n' "${SUMMARY[@]}"
(( FOUND )) || { fail 'no supported installed browser found'; exit 1; }
exit $FAILED
