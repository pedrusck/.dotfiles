#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/neovim"

mkdir -p "$HOME/.config/nvim"
ln -sf "$TOOL_DIR/init.lua" "$HOME/.config/nvim/init.lua"
ln -sfn "$TOOL_DIR/lua" "$HOME/.config/nvim/lua"
ln -sfn "$TOOL_DIR/lsp" "$HOME/.config/nvim/lsp"
ln -sfn "$TOOL_DIR/spell" "$HOME/.config/nvim/spell"
