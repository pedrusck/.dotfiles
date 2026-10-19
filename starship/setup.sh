#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/starship"
ln -sf "$TOOL_DIRECTORY/starship.toml" "$HOME/.config/starship/starship.toml"
