#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

CONFIG_DIRECTORY="$HOME/.config/nvim"

# Check all destinations before changing links, including the retired lsp link.
# Only links created for this checkout are managed here; preserve other content.
for entry in init.lua lua after spell lsp; do
	destination="$CONFIG_DIRECTORY/$entry"
	if [ -L "$destination" ]; then
		[ "$(readlink "$destination")" = "$TOOL_DIRECTORY/$entry" ] && continue
	elif [ ! -e "$destination" ]; then
		continue
	fi
	printf '%s\n' "Conflicting destination; move it aside before rerunning setup: $destination" >&2
	exit 1
done

mkdir -p "$CONFIG_DIRECTORY"
ln -sf "$TOOL_DIRECTORY/init.lua" "$CONFIG_DIRECTORY/init.lua"
ln -sfn "$TOOL_DIRECTORY/lua" "$CONFIG_DIRECTORY/lua"
ln -sfn "$TOOL_DIRECTORY/after" "$CONFIG_DIRECTORY/after"
ln -sfn "$TOOL_DIRECTORY/spell" "$CONFIG_DIRECTORY/spell"

# Migrate the old repository-owned link, even if its target no longer exists.
if [ -L "$CONFIG_DIRECTORY/lsp" ]; then
	rm "$CONFIG_DIRECTORY/lsp"
fi

# ── Spell dictionaries ──────────────────────────────────────────────
# Without a base .spl, setting 'spelllang' makes Neovim block on a
# "No spell file found for <lang>. Download? [y/N]" prompt. Pre-install the
# dictionaries for every language that has a custom wordlist, so per-buffer
# 'spelllang' never blocks.
#
# The language list is derived from the tracked `*.utf-8.add` wordlists, so
# adding a new language's wordlist is enough to pull its dictionary.
# The .spl files are large binaries and stay untracked (see .gitignore).
# Failures never abort setup: spell checking is optional.
install_spell_dictionaries() (
	url="https://ftp.nluug.nl/pub/vim/runtime/spell"
	runtime=""

	if command -v nvim >/dev/null 2>&1; then
		runtime=$(nvim --headless --clean -c 'echo $VIMRUNTIME' -c quit 2>&1)/spell
	fi

	# `en` and friends are skipped here: Neovim ships their dictionaries
	for wordlist in "$TOOL_DIRECTORY"/spell/*.utf-8.add; do
		[ -f "$wordlist" ] || continue
		language=${wordlist##*/}
		language=${language%.utf-8.add}
		target="$TOOL_DIRECTORY/spell/$language.utf-8.spl"
		if [ -f "$target" ] || { [ -n "$runtime" ] && [ -f "$runtime/$language.utf-8.spl" ]; }; then
			continue
		fi
		printf '%s\n' "  Downloading '$language' spell dictionary"

		curl --fail --silent --show-error --location --max-time 120 \
			--remove-on-error --output "$target.part" "$url/$language.utf-8.spl" || {
			printf '%s\n' "  warning: could not download '$language' dictionary from $url" >&2
			continue
		}

		# Guards against a captive portal or error page served with HTTP 200
		if ! file_signature=$(dd if="$target.part" bs=9 count=1 2>/dev/null) \
			|| [ "$file_signature" != VIMspell2 ]; then
			printf '%s\n' "  warning: '$language' download is not a Vim spell file, discarding" >&2
			rm -f "$target.part"
			continue
		fi

		mv "$target.part" "$target"
	done
)

install_spell_dictionaries
