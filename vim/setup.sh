#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/vim"

[ ! -d "$HOME/.vim" ] && mkdir -p "$HOME/.vim"
[ ! -d "$HOME/.vim/undo" ] && mkdir -p "$HOME/.vim/undo"
ln -sf "$TOOL_DIR/vimrc" "$HOME/.vim/vimrc"
