#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/tuicr"
ln -sf "$TOOL_DIRECTORY/config.toml" "$HOME/.config/tuicr/config.toml"
