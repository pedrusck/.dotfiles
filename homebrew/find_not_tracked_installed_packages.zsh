#!/usr/bin/env zsh

### Script to find currently installed packages not tracked in Brewfile ###

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BREWFILE="$SCRIPT_DIR/Brewfile"

if [[ ! -f "$BREWFILE" ]]; then
	echo "Error: Brewfile not found at $BREWFILE" >&2
	exit 1
fi

TEMP_DUMP=$(mktemp)
TRACKED_KEYS=$(mktemp)
INSTALLED_KEYS=$(mktemp)

trap 'rm -f "$TEMP_DUMP" "$TRACKED_KEYS" "$INSTALLED_KEYS"' EXIT

# Extract normalized package identifiers from a Brewfile-format file.
# Output: "type<TAB>identifier" per line, sorted and unique.
#
# Normalization rules:
# - Skips comment lines, blank lines, and "tap" entries
# - For brew/cask: uses the short name (last component after /)
#   so "amar1729/homebrew-formulae/browserpass" and
#   "amar1729/formulae/browserpass" both become "browserpass"
# - For mas: uses the App Store numeric ID (stable across name changes)
extract_packages() {
	local file="$1"
	while IFS= read -r line; do
		# Skip blank lines and comment-only lines
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ "$line" =~ ^(brew|cask)[[:space:]]+\"([^\"]+)\" ]]; then
			local pkg_type="${match[1]}"
			local full_name="${match[2]}"
			local short_name="${full_name##*/}"
			printf '%s\t%s\n' "$pkg_type" "$short_name"
		elif [[ "$line" =~ ^mas[[:space:]]+\"[^\"]*\",[[:space:]]*id:[[:space:]]*([0-9]+) ]]; then
			printf 'mas\t%s\n' "${match[1]}"
		fi
	done < "$file" | sort -u
}

echo "Dumping currently installed packages..."
brew bundle dump --file="$TEMP_DUMP" --force

echo "Comparing against Brewfile..."
extract_packages "$BREWFILE" > "$TRACKED_KEYS"
extract_packages "$TEMP_DUMP" > "$INSTALLED_KEYS"

# Build a lookup table: mas App Store ID -> app name (from the dump file)
typeset -A MAS_NAMES
while IFS= read -r line; do
	if [[ "$line" =~ ^mas[[:space:]]+\"([^\"]+)\",[[:space:]]*id:[[:space:]]*([0-9]+) ]]; then
		MAS_NAMES[${match[2]}]="${match[1]}"
	fi
done < "$TEMP_DUMP"

# Find installed packages not present in the Brewfile
NOT_TRACKED=$(comm -23 "$INSTALLED_KEYS" "$TRACKED_KEYS")

if [[ -z "$NOT_TRACKED" ]]; then
	echo ""
	echo "All installed packages are tracked in the Brewfile."
	exit 0
fi

echo ""
echo "=== Installed packages NOT tracked in Brewfile ==="
echo ""

count=0
for pkg_type in brew cask mas; do
	entries=$(printf '%s\n' "$NOT_TRACKED" | awk -F'\t' -v type="$pkg_type" '$1 == type {print $2}')
	if [[ -n "$entries" ]]; then
		if [[ "$pkg_type" == "mas" ]]; then
			# Build "name<TAB>id" pairs and sort alphabetically by name
			local sorted_entries=""
			while read -r id; do
				local app_name="${MAS_NAMES[$id]:-$id}"
				sorted_entries+="${app_name}"$'\t'"${id}"$'\n'
			done <<< "$entries"
			sorted_entries=$(printf '%s' "$sorted_entries" | sort -f)

			echo "--- ${pkg_type} ---"
			while IFS=$'\t' read -r app_name id; do
				echo "  $id ($app_name)"
				count=$((count + 1))
			done <<< "$sorted_entries"
			echo ""
		else
			# brew/cask: already sorted alphabetically
			echo "--- ${pkg_type} ---"
			while read -r name; do
				echo "  $name"
				count=$((count + 1))
			done <<< "$entries"
			echo ""
		fi
	fi
done

echo "Total: $count package(s) installed but not tracked."
