#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/cplt"
ln -sf "$TOOL_DIRECTORY/configuration.toml" "$HOME/.config/cplt/config.toml"

mkdir -p "$HOME/Developer/adesso_projects"
ln -sf "$TOOL_DIRECTORY/company_configuration.secret.toml" "$HOME/Developer/adesso_projects/cplt.toml"
