#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/leaf"

[ ! -d "$HOME/.config/leaf" ] && mkdir -p "$HOME/.config/leaf"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/leaf/config.toml"
ln -sf "$TOOL_DIR/gruvbox.toml" "$HOME/.config/leaf/gruvbox.toml"
