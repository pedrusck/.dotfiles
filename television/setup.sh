#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/television"

mkdir -p "$HOME/.config/television"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/television/config.toml"
command -v television >/dev/null 2>&1 && television update-channels
