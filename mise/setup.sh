#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/mise"

mkdir -p "$HOME/.config/mise"
ln -sf "$TOOL_DIR/config.toml" "$HOME/.config/mise/config.toml"
command -v mise &>/dev/null && mise trust "$HOME/.config/mise/config.toml"

mkdir -p "$HOME/Developer/adesso_projects"
ln -sf "$TOOL_DIR/mise_company_configuration.secret.toml" "$HOME/Developer/adesso_projects/mise.toml"
command -v mise &>/dev/null && mise trust "$HOME/Developer/adesso_projects/mise.toml"
