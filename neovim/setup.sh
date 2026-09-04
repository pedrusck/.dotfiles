#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/neovim"

mkdir -p "$HOME/.config/nvim"
ln -sf "$TOOL_DIR/init.lua" "$HOME/.config/nvim/init.lua"
ln -sfn "$TOOL_DIR/lua" "$HOME/.config/nvim/lua"
ln -sfn "$TOOL_DIR/lsp" "$HOME/.config/nvim/lsp"
ln -sfn "$TOOL_DIR/spell" "$HOME/.config/nvim/spell"

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
() {
	local url="https://ftp.nluug.nl/pub/vim/runtime/spell"
	local runtime language target file_signature

	(( $+commands[nvim] )) && runtime=$(nvim --headless --clean -c 'echo $VIMRUNTIME' -c quit 2>&1)/spell

	# `en` and friends are skipped here: Neovim ships their dictionaries
	local wanted=( "$TOOL_DIR"/spell/*.utf-8.add(N:t:r:r) )
	local have=( "$TOOL_DIR"/spell/*.utf-8.spl(N:t:r:r) ${runtime:+$runtime/*.utf-8.spl(N:t:r:r)} )

	for language in ${wanted:|have}; do
		print "  Downloading '$language' spell dictionary"
		target="$TOOL_DIR/spell/$language.utf-8.spl"

		curl --fail --silent --show-error --location --max-time 120 \
			--remove-on-error --output "$target.part" "$url/$language.utf-8.spl" || {
			print -ru2 -- "  warning: could not download '$language' dictionary from $url"
			continue
		}

		# Guards against a captive portal or error page served with HTTP 200
		read -k9 -u0 file_signature < "$target.part" || true
		[[ $file_signature == VIMspell2 ]] || {
			print -ru2 -- "  warning: '$language' download is not a Vim spell file, discarding"
			rm -f "$target.part"
			continue
		}

		mv "$target.part" "$target"
	done
}
