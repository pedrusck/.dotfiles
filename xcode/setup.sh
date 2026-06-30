#!/usr/bin/env zsh

setopt errexit nounset pipefail

TOOL_DIR="${DOTFILES_PATH:=$PWD}/xcode"

KEYBINDINGS_DIR="$HOME/Library/Developer/Xcode/UserData/KeyBindings"
if [ -d "$KEYBINDINGS_DIR" ]; then
	ln -sf "$TOOL_DIR/Vimious.idekeybindings" "$KEYBINDINGS_DIR/Vimious.idekeybindings"
fi

# Manual steps after running this script:
# 1. Open Xcode > Settings > Key Bindings and select "Vimious" as the active set.
# 2. Enable Vim Mode: Editor > Vim Mode.
# 3. Unbind Ctrl-6 from "Document Items" popup:
#    Xcode > Settings > Key Bindings > search "Document Items" > click the
#    shortcut field > press Delete to clear it. This frees Ctrl-6 (Ctrl-^),
#    which is the standard Vim binding for switching to the alternate file.
