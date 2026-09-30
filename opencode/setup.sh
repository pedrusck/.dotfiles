#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/opencode"

mkdir -p "$HOME/.config/opencode"
ln -sf "$TOOL_DIR/opencode.secret.json" "$HOME/.config/opencode/opencode.json"
ln -sf "$TOOL_DIR/tui.json" "$HOME/.config/opencode/tui.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install opencode
fi
