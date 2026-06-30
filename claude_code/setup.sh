#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/claude_code"

[ ! -d "$HOME/.claude" ] && mkdir -p "$HOME/.claude"
ln -sf "$TOOL_DIR/anthropic_key.secret.sh" "$HOME/.claude/anthropic_key.sh"
ln -sf "$TOOL_DIR/settings.json" "$HOME/.claude/settings.json"
