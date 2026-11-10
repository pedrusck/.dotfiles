#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CONFIGURATION_FILE="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"

mkdir -p "$(dirname -- "$CONFIGURATION_FILE")"
ln -sf "$TOOL_DIRECTORY/config.toml" "$CONFIGURATION_FILE"

if ! command -v herdr >/dev/null 2>&1; then
	printf '%s\n' 'Herdr is not on PATH; configuration linked, plugin installation skipped. After installing Herdr, rerun this setup script.'
	exit 0
fi

HERDR_CONFIG_PATH="$CONFIGURATION_FILE" herdr config check

herdr plugin install smarzban/herdr-file-viewer --yes
