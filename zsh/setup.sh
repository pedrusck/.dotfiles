#!/bin/sh

set -eu

TOOL_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

ln -sf "$TOOL_DIRECTORY/zshenv" "$HOME/.zshenv"

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
ln -sf "$TOOL_DIRECTORY/zshenv" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshenv"
ln -sf "$TOOL_DIRECTORY/zprofile" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zprofile"
ln -sf "$TOOL_DIRECTORY/zshrc" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc"

ln -sfn "$TOOL_DIRECTORY/zsh_additional_configuration" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zsh_additional_configuration"
ln -sfn "$TOOL_DIRECTORY/../shell_scripts/zsh" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zsh_functions"

touch "$HOME/.hushlogin" # Disable the "Last Login" message in new terminal sessions.
