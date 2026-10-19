#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.pi/agent"
ln -sf "$TOOL_DIRECTORY/models.secret.json" "$HOME/.pi/agent/models.json"
ln -sf "$TOOL_DIRECTORY/settings.secret.json" "$HOME/.pi/agent/settings.json"

mkdir -p "$HOME/.pi/agent/themes"
ln -sf "$TOOL_DIRECTORY/themes/gruvbox.json" "$HOME/.pi/agent/themes/gruvbox.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install pi
fi
