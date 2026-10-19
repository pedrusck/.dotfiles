#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/ghostty"
ln -sf "$TOOL_DIRECTORY/config" "$HOME/.config/ghostty/config"
