#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/opencode"
ln -sf "$TOOL_DIRECTORY/opencode.secret.json" "$HOME/.config/opencode/opencode.json"
ln -sf "$TOOL_DIRECTORY/cli.json" "$HOME/.config/opencode/cli.json"

if command -v herdr >/dev/null 2>&1; then
	herdr integration install opencode
fi
