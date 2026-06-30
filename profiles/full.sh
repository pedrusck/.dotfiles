#!/usr/bin/env zsh

# Full profile - development + all optional tools
# Usage: ./bootstrap.sh --profile full

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
	alacritty

	# Git tools
	lazygit
	gitui

	# Window management
	amethyst
	# rectangle  # Removed: Amethyst handles tiling; Rectangle shortcuts conflict with Amethyst

	# Dev tools
	mise
	television

	# Productivity
	leader_key

	# AI coding
	opencode
	claude_code
	pi-coding-agent

	# Shell prompt (alternative)
	oh_my_posh

	# Terminal multiplexer
	herdr

	# Xcode
	xcode
)
