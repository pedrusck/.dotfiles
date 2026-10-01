#!/usr/bin/env zsh
# Select an existing snapshot for manual restoration in configured Gecko browsers.
# No bookmark-content validation, browser shutdown, or profile-directory writes.

emulate -LR zsh
setopt errexit nounset pipefail
source "${0:A:h}/gecko_browsers.zsh"

function usage() {
	print -r -- 'Usage: restore_gecko_based_browser_bookmarks.zsh [SOURCE_FILE|SOURCE_DIR]
  -h, --help  Show help
The source defaults to the script directory. Directories select the newest raw
snapshot by filename timestamp/collision counter. An explicit file selects that
exact copy and may have any name. Relative paths use the current directory.
This helper only reports the file to select in the browser GUI. It does not
restore bookmarks itself or copy files into the managed bookmarkbackups folder.
GUI restoration replaces existing bookmarks rather than merging them.'
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

SOURCE=${0:A:h}
if (( $# )); then
	case $1 in
		-h|--help) usage; exit 0 ;;
		--) shift ;;
		-*) fail "unknown option: $1"; exit 1 ;;
	esac
	(( $# == 1 )) || { fail 'expected one source file or directory'; exit 1; }
	SOURCE=$1
fi
select_snapshot "$SOURCE" gecko jsonlz4
print -r -- "Snapshot selected (manual restore required): $REPLY"
typeset -a BROWSER_NAMES
for KEY in "${GECKO_BROWSERS[@]}"; do BROWSER_NAMES+=("${GECKO_BROWSER_NAMES[$KEY]}"); done
print -r -- "In a configured Gecko browser (${(j:, :)BROWSER_NAMES}): Bookmarks > Manage Bookmarks > Import and Backup > Restore > Choose File…
  Select: $REPLY
  Confirm replacement of the current bookmarks."
