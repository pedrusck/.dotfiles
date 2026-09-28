#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/leaf"

mkdir -p "$HOME/.config/leaf"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/leaf/config.toml"
ln -sf "$TOOL_DIR/gruvbox.toml" "$HOME/.config/leaf/gruvbox.toml"
