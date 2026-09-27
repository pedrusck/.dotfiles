#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/git"

mkdir -p "$HOME/.config/git"
ln -sfn "$TOOL_DIR/additional_configuration" "$HOME/.config/git/additional_configuration"
ln -sf "$TOOL_DIR/configuration" "$HOME/.config/git/config"
ln -sf "$TOOL_DIR/global_gitignore" "$HOME/.config/git/global_gitignore"
ln -sfn "$TOOL_DIR/template" "$HOME/.config/git/template"
