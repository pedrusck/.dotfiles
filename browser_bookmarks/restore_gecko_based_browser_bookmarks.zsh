#!/usr/bin/env zsh
# Stages a gecko_based_browser_bookmarks_*.secret.jsonlz4 snapshot (produced by
# extract_gecko_based_browser_bookmarks.zsh) into Floorp's bookmarkbackups folder
# so it can be restored from the GUI.
#
# Unlike Chromium-based browsers, Firefox-family browsers keep bookmarks inside
# places.sqlite (shared with history) rather than a swappable flat file, so this
# script cannot fully automate the restore. After it runs, finish manually in
# Floorp: Bookmarks → Manage Bookmarks → Import and Backup → Restore → pick the
# staged date → confirm.
#
# Usage: restore_gecko_based_browser_bookmarks.zsh [SOURCE_FILE|SOURCE_DIR]
#   SOURCE_FILE: a specific gecko_based_browser_bookmarks_*.secret.jsonlz4 snapshot.
#   SOURCE_DIR:  a directory to search for the newest matching snapshot (default: $PWD).

setopt errexit nounset pipefail

SOURCE="${1:-$PWD}"

if [[ -f "$SOURCE" ]]; then
	SOURCE_FILE="$SOURCE"
elif [[ -d "$SOURCE" ]]; then
	typeset -a SNAPSHOT_FILES=("$SOURCE"/gecko_based_browser_bookmarks_*.secret.jsonlz4(N))
	(( ${#SNAPSHOT_FILES} > 0 )) || { print "Error: no snapshot files found in $SOURCE"; exit 1 }

	SOURCE_FILE="${SNAPSHOT_FILES[1]}"
	for SNAPSHOT_FILE in "${SNAPSHOT_FILES[@]:1}"; do
		[[ "$SNAPSHOT_FILE" -nt "$SOURCE_FILE" ]] && SOURCE_FILE="$SNAPSHOT_FILE"
	done
else
	print "Error: source not found: $SOURCE"
	exit 1
fi

[[ -s "$SOURCE_FILE" ]] || { print "Error: source file is empty: $SOURCE_FILE"; exit 1 }

MAGIC=$(dd if="$SOURCE_FILE" bs=1 count=7 2>/dev/null)
[[ "$MAGIC" == "mozLz40" ]] \
	|| print -u2 "Warning: $SOURCE_FILE does not look like a mozLz40 bookmarks backup; continuing anyway."

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

[[ -n "$PROFILE_REL" ]] || { print "Error: could not resolve Floorp's default profile."; exit 1 }

PROFILE_DIR="$FLOORP_ROOT/$PROFILE_REL"
[[ -d "$PROFILE_DIR" ]] || { print "Error: Floorp profile directory not found: $PROFILE_DIR"; exit 1 }

BACKUPS_DIR="$PROFILE_DIR/bookmarkbackups"
mkdir -p "$BACKUPS_DIR"

TODAY=$(date '+%Y-%m-%d')
DEST="$BACKUPS_DIR/bookmarks-$TODAY.jsonlz4"
typeset -i SUFFIX=2
while [[ -e "$DEST" ]]; do
	DEST="$BACKUPS_DIR/bookmarks-${TODAY}_${SUFFIX}.jsonlz4"
	(( SUFFIX += 1 ))
done

if pgrep -x floorp >/dev/null; then
	print "Quitting Floorp…"
	osascript -e 'quit app "Floorp"' >/dev/null

	typeset -i WAITED=0
	while pgrep -x floorp >/dev/null; do
		(( WAITED >= 10 )) && { print "Error: Floorp did not quit in time."; exit 1 }
		sleep 1
		(( WAITED += 1 ))
	done
fi

cp -- "$SOURCE_FILE" "$DEST"

[[ $(md5 -q "$SOURCE_FILE") == $(md5 -q "$DEST") ]] \
	|| { print "Error: copy verification failed."; exit 1 }

print "Staged: $SOURCE_FILE -> $DEST"

open -a Floorp
print "Floorp relaunched."
print
print "To finish the restore in Floorp:"
print "  Bookmarks → Manage Bookmarks → Import and Backup → Restore → ${TODAY} → confirm."
