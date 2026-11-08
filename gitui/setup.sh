#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CONFIGURATION_DIRECTORY="${XDG_CONFIG_HOME:-$HOME/.config}/gitui"

mkdir -p "$CONFIGURATION_DIRECTORY"
ln -sf "$TOOL_DIRECTORY/key_bindings.ron" "$CONFIGURATION_DIRECTORY/key_bindings.ron"
