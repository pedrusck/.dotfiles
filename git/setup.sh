#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/git"

[ ! -d "$HOME/.config/git" ] && mkdir -p "$HOME/.config/git"
ln -sfn "$TOOL_DIR/additional_configuration" "$HOME/.config/git/additional_configuration"
ln -sf "$TOOL_DIR/configuration" "$HOME/.config/git/config"
ln -sf "$TOOL_DIR/global_gitignore" "$HOME/.config/git/global_gitignore"
ln -sfn "$TOOL_DIR/global_hooks" "$HOME/.config/git/global_hooks"

# Run the gitleaks secret-scanning pre-commit hook in every repo via a
# global core.hooksPath. The global hook chains to each repo's local
# pre-commit hook, and a repo's own (local) core.hooksPath still wins.
git config --global core.hooksPath "$HOME/.config/git/global_hooks"
