#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/pi-coding-agent"

mkdir -p "$HOME/.pi/agent"
ln -sf "$TOOL_DIR/models.secret.json" "$HOME/.pi/agent/models.json"
ln -sf "$TOOL_DIR/settings.secret.json" "$HOME/.pi/agent/settings.json"

mkdir -p "$HOME/.pi/agent/themes"
ln -sf "$TOOL_DIR/themes/gruvbox.json" "$HOME/.pi/agent/themes/gruvbox.json"
