#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/leader_key"

[ ! -d "$HOME/.config/leader_key" ] && mkdir -p "$HOME/.config/leader_key"
ln -sf "$TOOL_DIR/config.json" "$HOME/.config/leader_key/config.json"

# Setup config directory in Preferences... > Advanced and Reload from file in Preferences... > General
