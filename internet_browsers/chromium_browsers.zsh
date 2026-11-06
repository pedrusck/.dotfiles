#!/usr/bin/env zsh
# Chromium browsers and macOS locations. Source from Zsh.
# Browser order breaks ties during extraction.

typeset -a CHROMIUM_BROWSERS=(helium brave chrome)

# Names used for application bundles and main-process detection.
typeset -A CHROMIUM_BROWSER_NAMES=(
	helium Helium
	brave 'Brave Browser'
	chrome 'Google Chrome'
)

typeset -A CHROMIUM_BROWSER_ROOTS=(
	helium "$HOME/Library/Application Support/net.imput.helium"
	brave "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
	chrome "$HOME/Library/Application Support/Google/Chrome"
)
