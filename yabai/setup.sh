#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/yabai"
ln -sf "$TOOL_DIRECTORY/yabairc" "$HOME/.config/yabai/yabairc"
