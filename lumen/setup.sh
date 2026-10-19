#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/lumen"
ln -sf "$TOOL_DIRECTORY/lumen.config.json" "$HOME/.config/lumen/lumen.config.json"
