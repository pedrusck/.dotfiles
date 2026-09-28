#!/bin/sh

set -eu

TOOL_DIR="${DOTFILES_PATH:=$PWD}/claude_code"

mkdir -p "$HOME/.claude"
ln -sf "$TOOL_DIR/anthropic_key.secret.sh" "$HOME/.claude/anthropic_key.sh"
ln -sf "$TOOL_DIR/settings.json" "$HOME/.claude/settings.json"
