#!/usr/bin/env zsh

### Master setup script for macOS ###
#
# Usage:
#   ./bootstrap.sh --profile <core|development|full> [--package-manager <homebrew|nix>]
#
# Profiles:
#   core        - Minimal shell environment (zsh, git, vim, ssh, starship)
#   development - Core + dev tools (neovim, ghostty, lazygit, amethyst, mise, AI tools, etc.)
#   full        - Development + all optional tools (alacritty, herdr, xcode, etc.)
#
# Package managers:
#   homebrew    - Install CLI tools via Homebrew (default)
#   nix         - Install CLI tools via Nix (nix-darwin); casks and Mac App Store apps still use Homebrew
#

set -euo pipefail

### Helpers ###

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

function print_green() { printf "${GREEN}%s${RESET}\n" "$1"; }
function print_red() { printf "${RED}%s${RESET}\n" "$1"; }
function print_yellow() { printf "${YELLOW}%s${RESET}\n" "$1"; }

DOTFILES_PATH=$(cd "$(dirname "$0")"; pwd -P)

### Parse arguments ###

PROFILE=""
PACKAGE_MANAGER="homebrew"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--profile)
			PROFILE="$2"
			shift 2
			;;
		--package-manager)
			PACKAGE_MANAGER="$2"
			shift 2
			;;
		--help|-h)
			printf "Usage: %s --profile <core|development|full> [--package-manager <homebrew|nix>]\n" "$0"
			printf "\nProfiles:\n"
			printf "  core        - Minimal shell environment\n"
			printf "  development - Core + dev tools\n"
			printf "  full        - Development + all optional tools\n"
			printf "\nPackage managers:\n"
			printf "  homebrew    - Install CLI tools via Homebrew (default)\n"
			printf "  nix         - Install CLI tools via Nix (nix-darwin)\n"
			exit 0
			;;
		*)
			print_red "Unknown argument: $1"
			exit 1
			;;
	esac
done

if [[ -z "$PROFILE" ]]; then
	print_red "Error: --profile is required. Use --help for usage."
	exit 1
fi

PROFILE_FILE="$DOTFILES_PATH/profiles/$PROFILE.sh"
if [[ ! -f "$PROFILE_FILE" ]]; then
	print_red "Error: Profile '$PROFILE' not found. Available profiles: core, development, full"
	exit 1
fi

if [[ "$PACKAGE_MANAGER" != "homebrew" && "$PACKAGE_MANAGER" != "nix" ]]; then
	print_red "Error: Invalid package manager '$PACKAGE_MANAGER'. Use 'homebrew' or 'nix'."
	exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
	print_red "Error: This script only supports macOS."
	exit 1
fi

### Load profile ###

source "$PROFILE_FILE"
print_green "Setting up macOS with profile '$PROFILE' using $PACKAGE_MANAGER"
print_green "Tools to configure: ${PROFILE_TOOLS[*]}"

### Get sudo privileges ###

sudo -v

# Keep sudo alive during the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

### Inhibit sleep during setup ###

print_green "Saving current system sleep time settings"

CURRENT_COMPUTER_SLEEP_TIME=$(sudo systemsetup -getcomputersleep 2>/dev/null | grep -o -E '[0-9]+' || echo "")
CURRENT_DISPLAY_SLEEP_TIME=$(sudo systemsetup -getdisplaysleep 2>/dev/null | grep -o -E '[0-9]+' || echo "")
CURRENT_HARDDISK_SLEEP_TIME=$(sudo systemsetup -getharddisksleep 2>/dev/null | grep -o -E '[0-9]+' || echo "")

sudo systemsetup -setcomputersleep "Never" 2>/dev/null
sudo systemsetup -setdisplaysleep "Never" 2>/dev/null
sudo systemsetup -setharddisksleep "Never" 2>/dev/null

function restore_sleep_settings() {
	print_green "Restoring system sleep time settings"
	[[ -n "$CURRENT_COMPUTER_SLEEP_TIME" ]] && sudo systemsetup -setcomputersleep "$CURRENT_COMPUTER_SLEEP_TIME" 2>/dev/null
	[[ -n "$CURRENT_DISPLAY_SLEEP_TIME" ]] && sudo systemsetup -setdisplaysleep "$CURRENT_DISPLAY_SLEEP_TIME" 2>/dev/null
	[[ -n "$CURRENT_HARDDISK_SLEEP_TIME" ]] && sudo systemsetup -setharddisksleep "$CURRENT_HARDDISK_SLEEP_TIME" 2>/dev/null
}

trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; restore_sleep_settings' EXIT

### Install Xcode command line tools ###

if ! xcode-select -p &>/dev/null; then
	print_green "Installing Xcode command line tools"
	xcode-select --install

	# Wait for installation to complete
	until xcode-select -p &>/dev/null; do
		sleep 5
	done
else
	print_green "Xcode command line tools already installed"
fi

# Accept the Xcode license if Xcode is installed (detected via the Spotlight index by bundle ID)
if mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | grep -q .; then
	sudo xcodebuild -license accept 2>/dev/null || true
fi

### Install packages ###

if [[ "$PACKAGE_MANAGER" == "homebrew" ]]; then
	# Install Homebrew if not present
	if ! command -v brew &>/dev/null; then
		print_green "Installing Homebrew"
		# NOTE: Fetches installer from HEAD. Homebrew does not publish
		# per-release checksums for the installer script. This is the
		# officially recommended installation method.
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		eval "$(/opt/homebrew/bin/brew shellenv)"
	fi

	brew update --force --quiet

	print_green "Installing Homebrew packages"
	brew bundle --file="$DOTFILES_PATH/homebrew/Brewfile" 2>/dev/null

elif [[ "$PACKAGE_MANAGER" == "nix" ]]; then
	# Install Nix if not present
	if ! command -v nix &>/dev/null; then
		print_green "Installing Nix"
		curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
	fi

	# Build and activate nix-darwin configuration
	print_green "Building nix-darwin configuration (CLI tools via Nix)"
	darwin-rebuild switch --flake "$DOTFILES_PATH/nix#macbook"

	# Install Homebrew for casks and Mac App Store apps only
	if ! command -v brew &>/dev/null; then
		print_green "Installing Homebrew (for GUI apps and Mac App Store)"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		eval "$(/opt/homebrew/bin/brew shellenv)"
	fi

	brew update --force --quiet

	# Install only casks and Mac App Store apps from Brewfile
	print_green "Installing GUI apps and Mac App Store apps via Homebrew"
	grep -E '^(cask |mas )' "$DOTFILES_PATH/homebrew/Brewfile" | brew bundle --file=- 2>/dev/null
fi

### Unlock git-crypt encrypted files ###

if command -v git-crypt &>/dev/null; then
	print_green "Unlocking git-crypt encrypted files"
	git -C "$DOTFILES_PATH" crypt unlock || print_red "git-crypt unlock failed. Ensure your GPG key is imported."
fi

### Create symbolic links for configuration files ###

print_green "Setting up configuration for selected tools"

for TOOL in "${PROFILE_TOOLS[@]}"; do
	SETUP_SCRIPT="$DOTFILES_PATH/$TOOL/setup.sh"

	if [[ -f "$SETUP_SCRIPT" ]]; then
		print_green "  Setting up $TOOL"
		DOTFILES_PATH="$DOTFILES_PATH" zsh "$SETUP_SCRIPT"
	else
		print_yellow "  Warning: No setup.sh found for '$TOOL', skipping"
	fi
done

### Generate SSH keys ###

print_green "Generating SSH keys"

# Function to generate a passphrase with 128 bits of entropy
function generate_passphrase() {
	dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64 | sed 's/=//g'
}

# Function to check if a SSH key is already added in the ssh agent
# $1: SSH key path
function is_key_already_in_agent() {
	if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$1" 2>/dev/null | awk '{print $2}')"; then
		return 0
	else
		return 1
	fi
}

# Function to generate a SSH key for a service
# $1: SSH key name
# $2: SSH key comment
function generate_ssh_key() {
	local PASSPHRASE SSH_KEY_PATH
	PASSPHRASE="$(generate_passphrase)"
	SSH_KEY_PATH="$HOME/.ssh/$1"

	# Generate SSH key if it does not exist
	if [[ -f "$SSH_KEY_PATH" ]]; then
		print_yellow "  SSH key '$1' already exists"
	else
		print_green "  Generating SSH key '$1'"
		ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$2" -N "$PASSPHRASE"
	fi

	# Add ssh key to the ssh-agent if it is not already added
	if is_key_already_in_agent "$SSH_KEY_PATH"; then
		print_yellow "  SSH key '$1' is already in the SSH agent"
	else
		print_green "  Adding SSH key '$1' to agent"

		# Use SSH_ASKPASS to automatically provide the passphrase
		local AUTO_ADD_SCRIPT
		AUTO_ADD_SCRIPT=$(umask 077 && mktemp)
		trap 'rm -f "$AUTO_ADD_SCRIPT"' INT TERM
		printf '#!/bin/sh\necho "%s"\n' "$PASSPHRASE" > "$AUTO_ADD_SCRIPT"
		chmod 500 "$AUTO_ADD_SCRIPT"

		DISPLAY=1 SSH_ASKPASS="$AUTO_ADD_SCRIPT" ssh-add --apple-use-keychain "$SSH_KEY_PATH" < /dev/null

		rm -f "$AUTO_ADD_SCRIPT"
		trap - INT TERM
	fi
}

SSH_SERVICES_FILE="$DOTFILES_PATH/ssh/ssh_services"
if [[ -f "$SSH_SERVICES_FILE" ]]; then
	typeset -a SSH_SERVICES
	while IFS= read -r LINE; do
		[[ -n "$LINE" ]] && SSH_SERVICES+=("$LINE")
	done < "$SSH_SERVICES_FILE"

	MACHINE_NAME="$(hostname -s | tr '[:upper:]' '[:lower:]')"

	for SSH_SERVICE in "${SSH_SERVICES[@]}"; do
		SSH_KEY_COMMENT="$MACHINE_NAME@$SSH_SERVICE"
		generate_ssh_key "$SSH_SERVICE" "$SSH_KEY_COMMENT"
	done
else
	print_yellow "No ssh/ssh_services file found, skipping SSH key generation"
fi

### Create projects directories ###

print_green "Creating projects directories"

[[ ! -d "$HOME/Projects/personal_projects" ]] && mkdir -p "$HOME/Projects/personal_projects"
[[ ! -L "$HOME/Projects/Personal Projects" ]] && ln -s "$HOME/Projects/personal_projects" "$HOME/Projects/Personal Projects"

### Update TeX Live packages ###

if command -v tlmgr &>/dev/null; then
	print_green "Updating TeX Live packages"
	sudo tlmgr update --self --all --reinstall-forcibly-removed || print_red "TeX Live update failed"
fi

### Summary ###

print_green "Setup complete!"
printf "  Profile:         %s\n" "$PROFILE"
printf "  Package manager: %s\n" "$PACKAGE_MANAGER"
printf "  Tools configured: %s\n" "${PROFILE_TOOLS[*]}"
