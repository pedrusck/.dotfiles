#!/usr/bin/env zsh

# Development profile - core + dev tools
# Usage: ./bootstrap.sh --profile development

PROFILE_TOOLS=(
	# Core
	zsh
	git
	vim
	ssh
	starship

	# Editors
	neovim

	# Terminal
	ghostty

	# Git tools
	lazygit
	gitui

	# Window management
	amethyst

	# Dev tools
	mise
	television

	# Productivity
	leader_key

	# AI coding
	opencode
	claude_code
	pi-coding-agent
)
