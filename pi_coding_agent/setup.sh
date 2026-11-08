#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CONFIGURATION_DIRECTORY="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

mkdir -p "$CONFIGURATION_DIRECTORY"
ln -sf "$TOOL_DIRECTORY/models.secret.json" "$CONFIGURATION_DIRECTORY/models.json"
ln -sf "$TOOL_DIRECTORY/settings.secret.json" "$CONFIGURATION_DIRECTORY/settings.json"
ln -sf "$TOOL_DIRECTORY/keybindings.json" "$CONFIGURATION_DIRECTORY/keybindings.json"

mkdir -p "$CONFIGURATION_DIRECTORY/themes"
ln -sf "$TOOL_DIRECTORY/themes/gruvbox.json" "$CONFIGURATION_DIRECTORY/themes/gruvbox.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install pi
fi
