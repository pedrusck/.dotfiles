#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/aerospace"
ln -sf "$TOOL_DIRECTORY/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
