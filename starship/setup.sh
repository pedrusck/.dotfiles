#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/starship"

mkdir -p "$HOME/.config/starship"
ln -sf "$TOOL_DIR/starship.toml" "$HOME/.config/starship/starship.toml"
