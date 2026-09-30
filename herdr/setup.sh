#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/herdr"

mkdir -p "$HOME/.config/herdr"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/herdr/config.toml"

if command -v herdr >/dev/null 2>&1; then
	herdr plugin install smarzban/herdr-file-viewer --yes
fi
