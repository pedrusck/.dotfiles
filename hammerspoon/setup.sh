#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/hammerspoon"

ln -sfn "$TOOL_DIR" "$HOME/.hammerspoon"
