#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

[ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh" || mkdir -m 700 -p "$HOME/.ssh"
ln -sf "$TOOL_DIRECTORY/configuration" "$HOME/.ssh/config"
ln -sfn "$TOOL_DIRECTORY/hosts" "$HOME/.ssh/hosts"

chmod 600 "$TOOL_DIRECTORY/configuration"
