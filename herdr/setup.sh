#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/herdr"

mkdir -p "$HOME/.config/herdr"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/herdr/config.toml"
