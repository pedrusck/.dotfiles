#!/usr/bin/env zsh
# Stages a gecko_based_browser_bookmarks_*.secret.jsonlz4 snapshot (produced by
# extract_gecko_based_browser_bookmarks.zsh) into Floorp's bookmarkbackups folder
# so it can be restored from the GUI.
#
# Unlike Chromium-based browsers, Firefox-family browsers keep bookmarks inside
# places.sqlite (shared with history) rather than a swappable flat file, so this
# script cannot fully automate the restore. After it runs, finish manually in
# Floorp: Bookmarks → Manage Bookmarks → Import and Backup → Restore →
# Choose File... → the reported backup → confirm.
# Identical backups are reused; Floorp is relaunched only if it was running.
#
# Usage: restore_gecko_based_browser_bookmarks.zsh [SOURCE_FILE|SOURCE_DIR]
#   SOURCE_FILE: a specific gecko_based_browser_bookmarks_*.secret.jsonlz4 snapshot.
#   SOURCE_DIR:  newest snapshot by filename timestamp (default: $PWD).

setopt errexit nounset pipefail

SOURCE="${1:-$PWD}"

if [[ -f "$SOURCE" ]]; then
	SOURCE_FILE="$SOURCE"
elif [[ -d "$SOURCE" ]]; then
	typeset -a SNAPSHOT_FILES=("$SOURCE"/gecko_based_browser_bookmarks_*.secret.jsonlz4(NOn[1]))
	(( ${#SNAPSHOT_FILES} > 0 )) || { print "Error: no snapshot files found in $SOURCE"; exit 1 }

	SOURCE_FILE="${SNAPSHOT_FILES[1]}"
else
	print "Error: source not found: $SOURCE"
	exit 1
fi

[[ -s "$SOURCE_FILE" ]] || { print "Error: source file is empty: $SOURCE_FILE"; exit 1 }

MAGIC=$(head -c 8 -- "$SOURCE_FILE")
[[ "$MAGIC" == $'mozLz40\0' ]] \
	|| { print -u2 "Error: not a mozLz40 bookmarks backup: $SOURCE_FILE"; exit 1 }

INSTALLS_INI="$HOME/Library/Application Support/Floorp/installs.ini"
PROFILES_INI="$HOME/Library/Application Support/Floorp/profiles.ini"
FLOORP_ROOT="$HOME/Library/Application Support/Floorp"

typeset PROFILE_REL=""
if [[ -f "$INSTALLS_INI" ]]; then
	PROFILE_REL=$(awk -F= '/^Default=/{print $2; exit}' "$INSTALLS_INI")
fi

if [[ -z "$PROFILE_REL" && -f "$PROFILES_INI" ]]; then
	PROFILE_REL=$(awk '
		/^\[/ {
			if (isdefault && path != "") defpath = path
			path = ""; isdefault = 0; next
		}
		/^Path=/ { sub(/^Path=/, ""); path = $0; next }
		/^Default=1/ { isdefault = 1; next }
		END { if (isdefault && path != "") defpath = path; print defpath }
	' "$PROFILES_INI")
fi

[[ -n "$PROFILE_REL" ]] || { print -u2 "Floorp default profile not found. Launch Floorp once, then rerun this helper."; exit 1 }

PROFILE_DIR="$FLOORP_ROOT/$PROFILE_REL"
[[ $PROFILE_REL == /* ]] && PROFILE_DIR=$PROFILE_REL
[[ -d "$PROFILE_DIR" ]] || { print -u2 "Floorp profile not found: $PROFILE_DIR. Launch Floorp once, then rerun this helper."; exit 1 }

BACKUPS_DIR="$PROFILE_DIR/bookmarkbackups"
mkdir -p "$BACKUPS_DIR"

function restore_reminder() {
	print -r -- "In Floorp: Bookmarks > Manage Bookmarks > Import and Backup > Restore > Choose File...
  Select: $1"
}

for BACKUP in "$BACKUPS_DIR"/bookmarks-*.jsonlz4(N); do
	if cmp -s "$SOURCE_FILE" "$BACKUP"; then
		print "Identical Floorp backup already present: $BACKUP"
		restore_reminder "$BACKUP"
		exit 0
	fi
done

typeset -i WAS_RUNNING=0
if pgrep -x floorp >/dev/null; then
	WAS_RUNNING=1
	print "Quitting Floorp…"
	osascript -e 'quit app "Floorp"' >/dev/null

	typeset -i WAITED=0
	while pgrep -x floorp >/dev/null; do
		(( WAITED >= 10 )) && { print "Error: Floorp did not quit in time."; exit 1 }
		sleep 1
		(( WAITED += 1 ))
	done
fi

TEMP=""
trap '[[ -z $TEMP ]] || rm -f -- "$TEMP"; if (( WAS_RUNNING )); then open -a Floorp; fi' EXIT
TODAY=$(date '+%Y-%m-%d')
DEST="$BACKUPS_DIR/bookmarks-$TODAY.jsonlz4"
typeset -i SUFFIX=2
while [[ -e "$DEST" ]]; do
	DEST="$BACKUPS_DIR/bookmarks-${TODAY}_${SUFFIX}.jsonlz4"
	(( SUFFIX += 1 ))
done

TEMP=$(mktemp "$BACKUPS_DIR/.bookmarks.restore.XXXXXX")
cp -- "$SOURCE_FILE" "$TEMP"
cmp -s "$SOURCE_FILE" "$TEMP" || { print -u2 "Error: copy verification failed."; exit 1 }
mv -- "$TEMP" "$DEST"
print "Staged: $SOURCE_FILE -> $DEST"
restore_reminder "$DEST"
