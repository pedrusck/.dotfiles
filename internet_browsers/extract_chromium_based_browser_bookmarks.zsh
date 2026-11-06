#!/usr/bin/env zsh
# Capture one on-disk local Bookmarks store from configured Chromium browsers.
# Pending browser writes are not flushed. Account/encrypted stores are not merged.

emulate -LR zsh
setopt errexit nounset pipefail
umask 077
source "${0:A:h}/chromium_browsers.zsh"

function usage() {
	print -r -- "Usage: extract_chromium_based_browser_bookmarks.zsh [OPTIONS] [OUTPUT_DIR]
  --browser NAME       Source browser: ${(j:|:)CHROMIUM_BROWSERS}|all (default: all)
  --profile DIRECTORY  Explicit profile; requires a single --browser
  --source FILE        Explicit on-disk bookmark file
  -h, --help           Show help
OUTPUT_DIR defaults to the current directory. Automatic selection uses the
newest modification time across matching profiles; ties keep the first found.
An existing same-second snapshot is never overwritten; retry in the next second.
Only one source is copied. Close the source browser first for a flushed snapshot.
Restore with restore_chromium_based_browser_bookmarks.zsh to all installed
configured Chromium browsers (Default profiles unless overridden)."
}

function fail() {
	print -ru2 -- "Error: $*"
	return 1
}

# Sets BROWSER, PROFILE, SOURCE_FILE, and OUTPUT_DIR; browser validation follows.
function parse_extract_options() {
	local -i output_set=0
	BROWSER=all PROFILE="" SOURCE_FILE="" OUTPUT_DIR=$PWD
	while (( $# )); do
		case $1 in
			-h|--help) usage; exit 0 ;;
			--browser|--profile|--source)
				(( $# >= 2 )) && [[ -n $2 ]] || { fail "missing value for $1"; return 1; }
				case $1 in
					--browser) BROWSER=$2 ;;
					--profile) PROFILE=$2 ;;
					--source) SOURCE_FILE=$2 ;;
				esac
				shift 2 ;;
			--)
				shift
				(( $# == 1 && ! output_set )) || { fail 'expected one output directory after --'; return 1; }
				OUTPUT_DIR=$1 output_set=1
				shift ;;
			-*) fail "unknown option: $1"; return 1 ;;
			*)
				(( ! output_set )) || { fail "unexpected argument: $1"; return 1; }
				OUTPUT_DIR=$1 output_set=1
				shift ;;
		esac
	done
	[[ -d $OUTPUT_DIR && -w $OUTPUT_DIR ]] || { fail "output directory is missing or unwritable: $OUTPUT_DIR"; return 1; }
	[[ -z $PROFILE || ( $BROWSER != all && -z $SOURCE_FILE ) ]] || { fail '--profile requires one --browser and cannot be combined with --source'; return 1; }
	[[ -z $PROFILE || -d $PROFILE ]] || { fail "profile not found: $PROFILE"; return 1; }
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

# Stage on the output filesystem, then publish without overwriting a snapshot.
# Same-second exports fail on collision; retry in the next second.
function export_snapshot() (
	# Explicit returns keep Zsh's function-local EXIT trap active on failure.
	unsetopt errexit
	local source=${1:A} output=${2:A} family=$3 extension=$4 temp="" dest stamp
	function cleanup_export() {
		local -i result=$? failed=0
		[[ -z $temp ]] || rm -f -- "$temp" || failed=1
		trap - EXIT
		exit $(( result ? result : failed ))
	}
	trap cleanup_export EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	[[ -f $source && -r $source && -s $source ]] || { fail "source is missing, unreadable, or empty: $source"; return 1; }
	stamp=$(date '+%Y%m%d_%H%M%S') || return 1
	dest="$output/${family}_based_browser_bookmarks_$stamp.secret.$extension"
	[[ ! -e $dest && ! -L $dest ]] || { fail "snapshot already exists: $dest; retry in the next second"; return 1; }
	temp=$(mktemp "$output/.bookmarks-export.XXXXXXXX") || return 1
	copy_snapshot "$source" "$temp" || return 1
	ln -h -- "$temp" "$dest" || { fail "could not publish snapshot: $dest"; return 1; }
	print -r -- "Source: $source"
	print -r -- "Saved: $dest"
)

parse_extract_options "$@"
[[ $BROWSER == all || ${CHROMIUM_BROWSERS[(Ie)$BROWSER]} -gt 0 ]] || { fail "unknown browser: $BROWSER"; exit 1; }

typeset -a CANDIDATES STORES BROWSERS
SELECTED_PROFILE=unknown
if [[ -n $SOURCE_FILE ]]; then
	SOURCE_FILE=${SOURCE_FILE:A}
	SELECTED_BROWSER=${BROWSER/all/explicit}
	[[ ${SOURCE_FILE:t} != Bookmarks ]] || SELECTED_PROFILE=${SOURCE_FILE:h}
else
	if [[ $BROWSER == all ]]; then BROWSERS=("${CHROMIUM_BROWSERS[@]}"); else BROWSERS=("$BROWSER"); fi
	for KEY in "${BROWSERS[@]}"; do
		if [[ -n $PROFILE ]]; then
			CANDIDATES=("${PROFILE:A}/Bookmarks"(N.))
		else
			CANDIDATES=("${CHROMIUM_BROWSER_ROOTS[$KEY]}"/*/Bookmarks(N.))
		fi
		for FILE in "${CANDIDATES[@]}"; do
			if [[ -z $SOURCE_FILE || $FILE -nt $SOURCE_FILE ]]; then
				SOURCE_FILE=$FILE SELECTED_BROWSER=$KEY SELECTED_PROFILE=${FILE:A:h}
			fi
		done
	done
fi
[[ -n $SOURCE_FILE ]] || { fail 'no bookmark file found'; exit 1; }
if [[ $SELECTED_PROFILE != unknown ]]; then
	STORES=("$SELECTED_PROFILE"/AccountBookmarks(N.) "$SELECTED_PROFILE"/Encrypted*Bookmarks*(N.))
	if (( ${#STORES} )); then
		print -ru2 -- "Additional stores in this profile are not included: ${(j:, :)STORES}"
	fi
fi
print -r -- "Browser: $SELECTED_BROWSER; profile: $SELECTED_PROFILE"
export_snapshot "$SOURCE_FILE" "$OUTPUT_DIR" chromium json
