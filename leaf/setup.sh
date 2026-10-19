#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/leaf"
ln -sf "$TOOL_DIRECTORY/config.toml" "$HOME/.config/leaf/config.toml"
ln -sf "$TOOL_DIRECTORY/gruvbox.toml" "$HOME/.config/leaf/gruvbox.toml"
