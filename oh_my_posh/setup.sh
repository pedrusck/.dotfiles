#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/oh_my_posh"

mkdir -p "$HOME/.config/oh_my_posh"
ln -sf "$TOOL_DIR/configuration.toml" "$HOME/.config/oh_my_posh/configuration.toml"
