#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/zsh"

ln -sf "$TOOL_DIR/zshenv" "$HOME/.zshenv"

[ ! -d "$HOME/.config/zsh" ] && mkdir -p "$HOME/.config/zsh"
ln -sf "$TOOL_DIR/zprofile" "$HOME/.config/zsh/.zprofile"
ln -sf "$TOOL_DIR/zshrc" "$HOME/.config/zsh/.zshrc"
ln -sf "$TOOL_DIR/zsh_aliases" "$HOME/.config/zsh/zsh_aliases"
ln -sfn "$TOOL_DIR/zsh_additional_configuration" "$HOME/.config/zsh/zsh_additional_configuration"
ln -sfn "${DOTFILES_PATH:=$PWD}/shell_scripts/zsh" "$HOME/.config/zsh/zsh_functions"
ln -sfn "${DOTFILES_PATH:=$PWD}/shell_scripts/bash" "$HOME/.config/zsh/bash_functions"

touch ~/.hushlogin # disable the "Last Login" message on new terminal session
