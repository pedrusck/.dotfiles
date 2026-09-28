#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/aero_space"

mkdir -p "$HOME/.config/aerospace"
ln -sf "$TOOL_DIR/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
