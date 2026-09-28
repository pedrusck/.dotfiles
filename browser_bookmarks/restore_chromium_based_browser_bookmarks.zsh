#!/usr/bin/env zsh
# Restores a chromium_based_browser_bookmarks_*.secret.json snapshot (produced by
# extract_chromium_based_browser_bookmarks.zsh) into Helium by quitting the browser,
# backing up and replacing its Default/Bookmarks file. Relaunches only if running.
#
# Usage: restore_chromium_based_browser_bookmarks.zsh [SOURCE_FILE|SOURCE_DIR]
#   SOURCE_FILE: a specific chromium_based_browser_bookmarks_*.secret.json snapshot.
#   SOURCE_DIR:  newest snapshot by filename timestamp (default: $PWD).

setopt errexit nounset pipefail

SOURCE="${1:-$PWD}"

if [[ -f "$SOURCE" ]]; then
	SOURCE_FILE="$SOURCE"
elif [[ -d "$SOURCE" ]]; then
	typeset -a SNAPSHOT_FILES=("$SOURCE"/chromium_based_browser_bookmarks_*.secret.json(NOn[1]))
	(( ${#SNAPSHOT_FILES} > 0 )) || { print "Error: no snapshot files found in $SOURCE"; exit 1 }

	SOURCE_FILE="${SNAPSHOT_FILES[1]}"
else
	print "Error: source not found: $SOURCE"
	exit 1
fi

[[ -s "$SOURCE_FILE" ]] || { print "Error: source file is empty: $SOURCE_FILE"; exit 1 }
jq -e '.version == 1 and (.roots | type == "object")' "$SOURCE_FILE" >/dev/null \
	|| { print -u2 "Error: not a Chromium bookmarks snapshot: $SOURCE_FILE"; exit 1 }

PROFILE_DIR="$HOME/Library/Application Support/net.imput.helium/Default"
[[ -d "$PROFILE_DIR" ]] || { print -u2 "Helium profile not initialized. Launch Helium once, then rerun this helper."; exit 1 }

DEST="$PROFILE_DIR/Bookmarks"
typeset -i WAS_RUNNING=0

if pgrep -x Helium >/dev/null; then
	WAS_RUNNING=1
	print "Quitting Helium…"
	osascript -e 'quit app "Helium"' >/dev/null

	typeset -i WAITED=0
	while pgrep -x Helium >/dev/null; do
		(( WAITED >= 10 )) && { print "Error: Helium did not quit in time."; exit 1 }
		sleep 1
		(( WAITED += 1 ))
	done
fi

TEMP=""
trap '[[ -z $TEMP ]] || rm -f -- "$TEMP"; if (( WAS_RUNNING )); then open -a Helium; fi' EXIT
if cmp -s "$SOURCE_FILE" "$DEST"; then
	print "Helium bookmarks already match: $SOURCE_FILE"
else
	if [[ -f $DEST ]]; then
		BACKUP=$(mktemp "$DEST.before-restore.XXXXXX")
		cp -p -- "$DEST" "$BACKUP"
		print "Previous bookmarks saved: $BACKUP"
	fi
	# Verify a complete copy before atomically replacing the live bookmarks file.
	TEMP=$(mktemp "$PROFILE_DIR/.Bookmarks.restore.XXXXXX")
	cp -- "$SOURCE_FILE" "$TEMP"
	cmp -s "$SOURCE_FILE" "$TEMP" || { print -u2 "Error: copy verification failed."; exit 1 }
	mv -f -- "$TEMP" "$DEST"
	print "Restored: $SOURCE_FILE -> $DEST"
fi
