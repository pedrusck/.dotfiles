#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$HOME/.config/mise"
ln -sf "$TOOL_DIRECTORY/configuration.toml" "$HOME/.config/mise/config.toml"
command -v mise >/dev/null 2>&1 && mise trust "$HOME/.config/mise/config.toml"

mkdir -p "$HOME/Developer/adesso_projects"
ln -sf "$TOOL_DIRECTORY/company_configuration.secret.toml" "$HOME/Developer/adesso_projects/mise.toml"
command -v mise >/dev/null 2>&1 && mise trust "$HOME/Developer/adesso_projects/mise.toml"
