#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/starship"

[ ! -d "$HOME/.config/starship" ] && mkdir -p "$HOME/.config/starship"
ln -sf "$TOOL_DIR/starship.toml" "$HOME/.config/starship/starship.toml"
