#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/zellij"
ln -sf "$TOOL_DIRECTORY/config.kdl" "$HOME/.config/zellij/config.kdl"

# Symlink the custom default layout (one pane + slim compact-bar, green frame)
mkdir -p "$HOME/.config/zellij/layouts"
ln -sf "$TOOL_DIRECTORY/layouts/default.kdl" "$HOME/.config/zellij/layouts/default.kdl"
