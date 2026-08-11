#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/yabai"

mkdir -p "$HOME/.config/yabai"
ln -sf "$TOOL_DIR/yabairc" "$HOME/.config/yabai/yabairc"
