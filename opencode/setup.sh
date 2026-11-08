#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CONFIGURATION_DIRECTORY="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

mkdir -p "$CONFIGURATION_DIRECTORY"
ln -sf "$TOOL_DIRECTORY/opencode.secret.json" "$CONFIGURATION_DIRECTORY/opencode.json"
ln -sf "$TOOL_DIRECTORY/cli.json" "$CONFIGURATION_DIRECTORY/cli.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install opencode
fi
