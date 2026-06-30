#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/hammerspoon"

ln -sfn "$TOOL_DIR" "$HOME/.hammerspoon"
