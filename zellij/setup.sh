#!/usr/bin/env zsh

set -euo pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/zellij"

[ ! -d "$HOME/.config/zellij" ] && mkdir -p "$HOME/.config/zellij"
ln -sf "$TOOL_DIR/config.kdl" "$HOME/.config/zellij/config.kdl"

# Symlink the custom default layout (one pane + slim compact-bar, green frame)
[ ! -d "$HOME/.config/zellij/layouts" ] && mkdir -p "$HOME/.config/zellij/layouts"
ln -sf "$TOOL_DIR/layouts/default.kdl" "$HOME/.config/zellij/layouts/default.kdl"
