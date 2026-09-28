#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/gitui"

mkdir -p "$HOME/.config/gitui"
ln -sf "$TOOL_DIR/key_config.ron" "$HOME/.config/gitui/key_config.ron"
