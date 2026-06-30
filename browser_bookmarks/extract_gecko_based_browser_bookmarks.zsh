#!/usr/bin/env zsh
# Copies the most recent bookmark backup (.jsonlz4) from Firefox, Zen, or Floorp
# to OUTPUT_DIR (default: ~/Desktop). Restore via: Bookmarks → Manage Bookmarks
# → Import and Backup → Restore → Choose File…

setopt errexit nounset pipefail

OUTPUT_DIR="${1:-$PWD}"
[[ -d "$OUTPUT_DIR" ]] || { print "Error: output directory not found: $OUTPUT_DIR"; exit 1 }

typeset -a PROFILE_PATHS=(
	"$HOME/Library/Application Support/Firefox/Profiles"
	"$HOME/Library/Application Support/Zen/Profiles"
	"$HOME/Library/Application Support/Floorp/Profiles"
)

typeset -a BACKUP_FILES=()
for PROFILE_PATH in "${PROFILE_PATHS[@]}"; do
	BACKUP_FILES+=("$PROFILE_PATH"/*/bookmarkbackups/*.jsonlz4(N))
done

(( ${#BACKUP_FILES} > 0 )) || { print "Error: no bookmark backups found."; exit 1 }

LATEST_FILE="${BACKUP_FILES[1]}"
for BACKUP_FILE in "${BACKUP_FILES[@]:1}"; do
	[[ "$BACKUP_FILE" -nt "$LATEST_FILE" ]] && LATEST_FILE="$BACKUP_FILE"
done

DEST="$OUTPUT_DIR/gecko_based_browser_bookmarks_$(date '+%Y%m%d_%H%M%S').secret.jsonlz4"
cp -- "$LATEST_FILE" "$DEST"

[[ $(md5 -q "$LATEST_FILE") == $(md5 -q "$DEST") ]] \
	|| { rm -f "$DEST"; print "Error: copy verification failed."; exit 1 }

print "Saved: $DEST"
