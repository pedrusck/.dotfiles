#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/ghostty"

mkdir -p "$HOME/.config/ghostty"
ln -sf "$TOOL_DIR/config" "$HOME/.config/ghostty/config"
