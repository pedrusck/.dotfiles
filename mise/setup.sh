#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/mise"

[ ! -d "$HOME/.config/mise" ] && mkdir -p "$HOME/.config/mise"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/mise/config.toml"
command -v mise &>/dev/null && mise trust "$HOME/.config/mise/config.toml"
