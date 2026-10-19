#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/oh_my_posh"
ln -sf "$TOOL_DIRECTORY/configuration.toml" "$HOME/.config/oh_my_posh/configuration.toml"
