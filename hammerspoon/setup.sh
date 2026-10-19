#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

ln -sfn "$TOOL_DIRECTORY" "$HOME/.hammerspoon"
