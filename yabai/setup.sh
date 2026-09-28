#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/yabai"

mkdir -p "$HOME/.config/yabai"
ln -sf "$TOOL_DIR/yabairc" "$HOME/.config/yabai/yabairc"
