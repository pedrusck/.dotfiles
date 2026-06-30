#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/alacritty"

[ ! -d "$HOME/.config/alacritty" ] && mkdir -p "$HOME/.config/alacritty"
ln -sf "$TOOL_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
ln -sf "$TOOL_DIR/gruvbox_material_medium_dark.toml" "$HOME/.config/alacritty/gruvbox_material_medium_dark.toml"
