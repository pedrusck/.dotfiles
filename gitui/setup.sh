#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/gitui"
ln -sf "$TOOL_DIRECTORY/key_config.ron" "$HOME/.config/gitui/key_config.ron"
