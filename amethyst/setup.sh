#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/amethyst"

mkdir -p "$HOME/.config/amethyst"
ln -sf "$TOOL_DIR/amethyst.yml" "$HOME/.config/amethyst/amethyst.yml"
