#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/leader_key"
ln -sf "$TOOL_DIRECTORY/config.json" "$HOME/.config/leader_key/config.json"

# Setup config directory in Preferences... > Advanced and Reload from file in Preferences... > General
