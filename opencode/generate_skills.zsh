#!/usr/bin/env zsh

setopt errexit nounset pipefail

SKILLS_DIR="$HOME/.config/opencode/skills"
mkdir -p "$SKILLS_DIR"

if (( $+commands[xcrun] )) && xcrun agent skills export --help >/dev/null 2>&1; then
	xcrun agent skills export --output-dir "$SKILLS_DIR/xcode-skills" --replace-existing
else
	print -- "Xcode: skipped (skill export unavailable)"
fi

if (( $+commands[herdr] )) && [[ "$(herdr --help)" == *--skill* ]]; then
	mkdir -p "$SKILLS_DIR/herdr"
	herdr --skill > "$SKILLS_DIR/herdr/SKILL.md"
else
	print -- "Herdr: skipped (skill export unavailable)"
fi

# Use home-level tools, not the caller's project; --global targets Claude.
MISE=( mise --no-env --no-hooks -C "$HOME" )
if (( $+commands[mise] )) && "${MISE[@]}" skills sync --help >/dev/null 2>&1; then
	"${MISE[@]}" skills sync --dir "$SKILLS_DIR/mise-skills" --prune
else
	print -- "mise: skipped (skill sync unavailable)"
fi

print -- "Skills refreshed in $SKILLS_DIR. Restart OpenCode to load them."
