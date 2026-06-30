#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/opencode"

[ ! -d "$HOME/.config/opencode" ] && mkdir -p "$HOME/.config/opencode"
ln -sf "$TOOL_DIR/opencode.secret.json" "$HOME/.config/opencode/opencode.json"
ln -sf "$TOOL_DIR/tui.json" "$HOME/.config/opencode/tui.json"
