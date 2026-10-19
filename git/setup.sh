#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/git"
ln -sfn "$TOOL_DIRECTORY/additional_configuration" "$HOME/.config/git/additional_configuration"
ln -sf "$TOOL_DIRECTORY/configuration" "$HOME/.config/git/config"
ln -sf "$TOOL_DIRECTORY/global_gitignore" "$HOME/.config/git/global_gitignore"
ln -sfn "$TOOL_DIRECTORY/template" "$HOME/.config/git/template"
