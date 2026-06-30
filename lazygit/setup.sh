#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/lazygit"

[ ! -d "$HOME/.config/lazygit" ] && mkdir -p "$HOME/.config/lazygit"
ln -sf "$TOOL_DIR/config.yml" "$HOME/.config/lazygit/config.yml"
