#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/tuicr"

mkdir -p "$HOME/.config/tuicr"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/tuicr/config.toml"
