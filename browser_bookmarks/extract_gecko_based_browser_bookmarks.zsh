#!/usr/bin/env zsh
# Copy one existing configured Gecko browser backup, not a live export.
# Output defaults to $PWD. Restore directly with the browser's Choose File… GUI.

emulate -LR zsh
setopt errexit nounset pipefail
umask 077
source "${0:A:h}/gecko_browsers.zsh"

function usage() {
	print -r -- "Usage: extract_gecko_based_browser_bookmarks.zsh [OPTIONS] [OUTPUT_DIR]
  --browser NAME       Source browser: ${(j:|:)GECKO_BROWSERS}|all (default: all)
  --profile DIRECTORY  Explicit profile; requires a single --browser
  --source FILE        Explicit existing .jsonlz4 backup
  -h, --help           Show help
OUTPUT_DIR defaults to the current directory. Automatic selection uses the
native backup filename date, then modification time for same-day backups.
Ties keep the first found. Standard Profiles directories are searched;
use --profile for external profiles. The original backup filename is printed.
This copies an existing backup: it does not export current browser bookmarks.
An existing same-second snapshot is never overwritten; retry in the next second."
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
[[ $BROWSER == all || ${GECKO_BROWSERS[(Ie)$BROWSER]} -gt 0 ]] || { fail "unknown browser: $BROWSER"; exit 1; }

typeset -a BROWSERS PROFILE_DIRS
LATEST_DATE=""
if [[ -n $SOURCE_FILE ]]; then
	SOURCE_FILE=${SOURCE_FILE:A}
	SELECTED_BROWSER=${BROWSER/all/explicit}
	SELECTED_PROFILE=unknown
	[[ ${SOURCE_FILE:h:t} != bookmarkbackups ]] || SELECTED_PROFILE=${SOURCE_FILE:h:h}
else
	if [[ $BROWSER == all ]]; then BROWSERS=("${GECKO_BROWSERS[@]}"); else BROWSERS=("$BROWSER"); fi
	for KEY in "${BROWSERS[@]}"; do
		if [[ -n $PROFILE ]]; then
			PROFILE_DIRS=("${PROFILE:A}")
		else
			ROOT=${GECKO_BROWSER_ROOTS[$KEY]}
			ALTERNATE_ROOT=${GECKO_BROWSER_ALTERNATE_ROOTS[$KEY]-}
			[[ -d $ROOT || -z $ALTERNATE_ROOT ]] || ROOT=$ALTERNATE_ROOT
			PROFILE_DIRS=("$ROOT"/Profiles/*(N/))
		fi
		for PROFILE_DIR in "${PROFILE_DIRS[@]}"; do
			for FILE in "$PROFILE_DIR"/bookmarkbackups/*.jsonlz4(N.); do
				# The date is browser metadata, not the last modification of the file.
				[[ ${FILE:t} =~ '^bookmarks-([0-9]{4}-[0-9]{2}-[0-9]{2})(_[[:alnum:]_=+-]+)*\.jsonlz4$' ]] || continue
				BACKUP_DATE=$match[1]
				if [[ -z $SOURCE_FILE || $BACKUP_DATE > $LATEST_DATE || ( $BACKUP_DATE == $LATEST_DATE && $FILE -nt $SOURCE_FILE ) ]]; then
					SOURCE_FILE=$FILE SELECTED_BROWSER=$KEY SELECTED_PROFILE=$PROFILE_DIR LATEST_DATE=$BACKUP_DATE
				fi
			done
		done
	done
fi
[[ -n $SOURCE_FILE ]] || { fail 'no bookmark backup found'; exit 1; }
print -r -- "Existing backup: ${SOURCE_FILE:t} (no fresh browser export was requested)."
print -r -- "Browser: $SELECTED_BROWSER; profile: $SELECTED_PROFILE"
export_snapshot "$SOURCE_FILE" "$OUTPUT_DIR" gecko jsonlz4
