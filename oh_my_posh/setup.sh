#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/oh_my_posh"

[ ! -d "$HOME/.config/oh_my_posh" ] && mkdir -p "$HOME/.config/oh_my_posh"
ln -sf "$TOOL_DIR/configuration.toml" "$HOME/.config/oh_my_posh/configuration.toml"
