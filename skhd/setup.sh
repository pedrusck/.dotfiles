#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/skhd"
ln -sf "$TOOL_DIRECTORY/skhdrc" "$HOME/.config/skhd/skhdrc"
