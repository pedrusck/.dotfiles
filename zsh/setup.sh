#!/bin/sh

set -eu

tool_dir="${DOTFILES_PATH:=$PWD}/zsh"

ln -sf "$tool_dir/zshenv" "$HOME/.zshenv"

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
ln -sf "$tool_dir/zshenv" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshenv"
ln -sf "$tool_dir/zprofile" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zprofile"
ln -sf "$tool_dir/zshrc" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc"

ln -sfn "$tool_dir/zsh_additional_configuration" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zsh_additional_configuration"
ln -sfn "$DOTFILES_PATH/shell_scripts/zsh" "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zsh_functions"

touch "$HOME/.hushlogin" # Disable the "Last Login" message in new terminal sessions.
