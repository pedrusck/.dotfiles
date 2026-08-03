#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/tuicr"

[ ! -d "$HOME/.config/tuicr" ] && mkdir -p "$HOME/.config/tuicr"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/tuicr/config.toml"
