#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/lumen"

mkdir -p "$HOME/.config/lumen"
ln -sf "$TOOL_DIR/lumen.config.json" "$HOME/.config/lumen/lumen.config.json"
