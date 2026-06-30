#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/skhd"

[ ! -d "$HOME/.config/skhd" ] && mkdir -p "$HOME/.config/skhd"
ln -sf "$TOOL_DIR/skhdrc" "$HOME/.config/skhd/skhdrc"
