#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/television"
ln -sf "$TOOL_DIRECTORY/config.toml" "$HOME/.config/television/config.toml"
command -v television >/dev/null 2>&1 && television update-channels
