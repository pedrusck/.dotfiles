#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/rumdl"
ln -sf "$TOOL_DIRECTORY/rumdl.toml" "$HOME/.config/rumdl/rumdl.toml"
