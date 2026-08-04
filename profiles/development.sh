#!/usr/bin/env zsh

# Development profile — the tools configured by bootstrap.zsh
# Usage: ./bootstrap.zsh --profile development --key-dir <path>

PROFILE_TOOLS=(
	# Core
	zsh
	git
	vim
	ssh
	starship

	# Editor
	neovim

	# Terminal
	ghostty

	# Git tools
	lazygit
	tuicr

	# Window management
	amethyst

	# Terminal multiplexer
	herdr

	# Dev tools
	mise
)
