#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
MISE_EXECUTABLE="$HOME/.local/bin/mise"

if [ ! -x "$MISE_EXECUTABLE" ]; then
	installer=$(curl -fsSL https://mise.run)
	printf '%s\n' "$installer" | MISE_INSTALL_PATH="$MISE_EXECUTABLE" sh
fi

mkdir -p "$HOME/.config/mise"
ln -sf "$TOOL_DIRECTORY/configuration.toml" "$HOME/.config/mise/config.toml"
"$MISE_EXECUTABLE" trust "$HOME/.config/mise/config.toml"

# TODO: Hide me?
mkdir -p "$HOME/Developer/adesso_projects"
ln -sf "$TOOL_DIRECTORY/company_configuration.secret.toml" "$HOME/Developer/adesso_projects/mise.toml"
"$MISE_EXECUTABLE" trust "$HOME/Developer/adesso_projects/mise.toml"
