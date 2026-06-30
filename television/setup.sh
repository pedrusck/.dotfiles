#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/television"

[ ! -d "$HOME/.config/television" ] && mkdir -p "$HOME/.config/television"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/television/config.toml"
command -v television &>/dev/null && television update-channels
