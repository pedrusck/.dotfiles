#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/skhd"

mkdir -p "$HOME/.config/skhd"
ln -sf "$TOOL_DIR/skhdrc" "$HOME/.config/skhd/skhdrc"
