#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/lazygit"
ln -sf "$TOOL_DIRECTORY/config.yml" "$HOME/.config/lazygit/config.yml"
