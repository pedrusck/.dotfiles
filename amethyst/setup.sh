#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/amethyst"
ln -sf "$TOOL_DIRECTORY/amethyst.yml" "$HOME/.config/amethyst/amethyst.yml"
