#!/usr/bin/env zsh
# Copies the most recent Bookmarks file from Chrome, Helium, or Brave on macOS
# to OUTPUT_DIR (default: ~/Desktop).
# Restore: replace the target browser's Default/Bookmarks file with this one
# (close the browser first), or import via chrome://bookmarks → ⋮ → Import.

setopt errexit nounset pipefail

OUTPUT_DIR="${1:-$PWD}"
[[ -d "$OUTPUT_DIR" ]] || { print "Error: output directory not found: $OUTPUT_DIR"; exit 1 }

typeset -a PROFILE_PATHS=(
	"$HOME/Library/Application Support/Google/Chrome"
	"$HOME/Library/Application Support/net.imput.helium"
	"$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
)

typeset -a BOOKMARK_FILES=()
for PROFILE_PATH in "${PROFILE_PATHS[@]}"; do
	BOOKMARK_FILES+=("$PROFILE_PATH"/*/Bookmarks(N))
done

(( ${#BOOKMARK_FILES} > 0 )) || { print "Error: no bookmark files found."; exit 1 }

LATEST_FILE="${BOOKMARK_FILES[1]}"
for BOOKMARK_FILE in "${BOOKMARK_FILES[@]:1}"; do
	[[ "$BOOKMARK_FILE" -nt "$LATEST_FILE" ]] && LATEST_FILE="$BOOKMARK_FILE"
done

DEST="$OUTPUT_DIR/chromium_based_browser_bookmarks_$(date '+%Y%m%d_%H%M%S').secret.json"
cp -- "$LATEST_FILE" "$DEST"

[[ $(md5 -q "$LATEST_FILE") == $(md5 -q "$DEST") ]] \
	|| { rm -f "$DEST"; print "Error: copy verification failed."; exit 1 }

print "Saved: $DEST"
