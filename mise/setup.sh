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

completion_registry_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions-sync"
mkdir -p "$completion_registry_dir"
ln -sf "$TOOL_DIRECTORY/completions-registry.toml" "$completion_registry_dir/registry.toml"

completion_dir="${MISE_COMPLETIONS_SYNC_ZSH_DIR:-${MISE_COMPLETIONS_SYNC_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions}/zsh}"
completion_script=$("$MISE_EXECUTABLE" completion zsh)
mkdir -p "$completion_dir"
printf '%s\n' "$completion_script" > "$completion_dir/_mise"

# TODO: Hide me?
mkdir -p "$HOME/Developer/adesso_projects"
ln -sf "$TOOL_DIRECTORY/company_configuration.secret.toml" "$HOME/Developer/adesso_projects/mise.toml"
"$MISE_EXECUTABLE" trust "$HOME/Developer/adesso_projects/mise.toml"
