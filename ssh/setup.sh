#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/ssh"

[ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh" || mkdir -m 700 -p "$HOME/.ssh"
ln -sf "$TOOL_DIR/configuration" "$HOME/.ssh/config"
ln -sfn "$TOOL_DIR/hosts" "$HOME/.ssh/hosts"

chmod 600 "$TOOL_DIR/configuration"
