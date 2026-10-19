#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/alacritty"
ln -sf "$TOOL_DIRECTORY/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
ln -sf "$TOOL_DIRECTORY/gruvbox_material_medium_dark.toml" "$HOME/.config/alacritty/gruvbox_material_medium_dark.toml"
