#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/herdr"
ln -sf "$TOOL_DIRECTORY/config.toml" "$HOME/.config/herdr/config.toml"

if command -v herdr >/dev/null 2>&1; then
	herdr plugin install smarzban/herdr-file-viewer --yes
fi
