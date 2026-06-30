#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/neovim"

[ ! -d "$HOME/.config/nvim" ] && mkdir -p "$HOME/.config/nvim"
ln -sf "$TOOL_DIR/init.lua" "$HOME/.config/nvim/init.lua"
ln -sfn "$TOOL_DIR/plugin" "$HOME/.config/nvim/plugin"
ln -sfn "$TOOL_DIR/lsp" "$HOME/.config/nvim/lsp"
ln -sfn "$TOOL_DIR/spell" "$HOME/.config/nvim/spell"
