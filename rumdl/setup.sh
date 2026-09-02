#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/rumdl"

mkdir -p "$HOME/.config/rumdl"
ln -sf "$TOOL_DIR/rumdl.toml" "$HOME/.config/rumdl/rumdl.toml"
