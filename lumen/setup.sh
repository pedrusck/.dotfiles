#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/lumen"

[ ! -d "$HOME/.config/lumen" ] && mkdir -p "$HOME/.config/lumen"
ln -sf "$TOOL_DIR/lumen.config.json" "$HOME/.config/lumen/lumen.config.json"
