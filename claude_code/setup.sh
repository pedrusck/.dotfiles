#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.claude"
ln -sf "$TOOL_DIRECTORY/anthropic_key.secret.sh" "$HOME/.claude/anthropic_key.sh"
ln -sf "$TOOL_DIRECTORY/settings.json" "$HOME/.claude/settings.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install claude
fi
