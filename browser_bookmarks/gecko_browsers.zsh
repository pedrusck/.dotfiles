#!/usr/bin/env zsh
# Gecko browsers and macOS locations. Source from Zsh.
# Browser order breaks ties during extraction.

typeset -a GECKO_BROWSERS=(firefox zen floorp librewolf)

typeset -A GECKO_BROWSER_NAMES=(
	firefox Firefox
	zen Zen
	floorp Floorp
	librewolf LibreWolf
)

typeset -A GECKO_BROWSER_ROOTS=(
	firefox "$HOME/Library/Application Support/Firefox"
	zen "$HOME/Library/Application Support/zen"
	floorp "$HOME/Library/Application Support/Floorp"
	librewolf "$HOME/Library/Application Support/LibreWolf"
)

# Used only when the primary root directory does not exist.
typeset -A GECKO_BROWSER_ALTERNATE_ROOTS=(
	zen "$HOME/Library/Application Support/Zen"
)
