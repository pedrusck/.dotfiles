#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CONFIGURATION_DIRECTORY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CONFIGURATION_DIRECTORY"

ln -sf "$TOOL_DIRECTORY/anthropic_key.secret.sh" "$CONFIGURATION_DIRECTORY/anthropic_key.sh"
ln -sf "$TOOL_DIRECTORY/settings.json" "$CONFIGURATION_DIRECTORY/settings.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install claude
else
	printf '%s\n' 'Herdr is not on PATH; Claude integration skipped. After installing Herdr, run: herdr integration install claude'
fi
