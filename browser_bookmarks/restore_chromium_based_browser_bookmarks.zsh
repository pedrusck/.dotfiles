#!/usr/bin/env zsh
# Restores a chromium_based_browser_bookmarks_*.secret.json snapshot (produced by
# extract_chromium_based_browser_bookmarks.zsh) into Helium by quitting the browser,
# replacing its Default/Bookmarks file, and relaunching it.
#
# Usage: restore_chromium_based_browser_bookmarks.zsh [SOURCE_FILE|SOURCE_DIR]
#   SOURCE_FILE: a specific chromium_based_browser_bookmarks_*.secret.json snapshot.
#   SOURCE_DIR:  a directory to search for the newest matching snapshot (default: $PWD).

setopt errexit nounset pipefail

SOURCE="${1:-$PWD}"

if [[ -f "$SOURCE" ]]; then
	SOURCE_FILE="$SOURCE"
elif [[ -d "$SOURCE" ]]; then
	typeset -a SNAPSHOT_FILES=("$SOURCE"/chromium_based_browser_bookmarks_*.secret.json(N))
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

PROFILE_DIR="$HOME/Library/Application Support/net.imput.helium/Default"
[[ -d "$PROFILE_DIR" ]] || { print "Error: Helium profile directory not found: $PROFILE_DIR"; exit 1 }

DEST="$PROFILE_DIR/Bookmarks"

if pgrep -x Helium >/dev/null; then
	print "Quitting Helium…"
	osascript -e 'quit app "Helium"' >/dev/null

	typeset -i WAITED=0
	while pgrep -x Helium >/dev/null; do
		(( WAITED >= 10 )) && { print "Error: Helium did not quit in time."; exit 1 }
		sleep 1
		(( WAITED += 1 ))
	done
fi

cp -- "$SOURCE_FILE" "$DEST"

[[ $(md5 -q "$SOURCE_FILE") == $(md5 -q "$DEST") ]] \
	|| { print "Error: copy verification failed."; exit 1 }

print "Restored: $SOURCE_FILE -> $DEST"

open -a Helium
print "Helium relaunched."
