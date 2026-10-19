#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.vim"
mkdir -p "$HOME/.vim/undo"
ln -sf "$TOOL_DIRECTORY/vimrc" "$HOME/.vim/vimrc"
