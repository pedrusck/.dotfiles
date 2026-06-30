#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/gitui"

[ ! -d "$HOME/.config/gitui" ] && mkdir -p "$HOME/.config/gitui"
ln -sf "$TOOL_DIR/key_config.ron" "$HOME/.config/gitui/key_config.ron"
