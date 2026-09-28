#!/usr/bin/env zsh

## macOS bootstrap for Apple Silicon
##
## Usage
## /bin/zsh -f bootstrap_macos.zsh --key-dir "/Volumes/MY_KEYS" [options]
## --key-dir <path>      Required directory containing GPG exports (.asc, .gpg)
## --profile <name>      Select configurations (default: development)
## --skip-keybindings    Leave macOS keyboard shortcuts unchanged
## -h, --help            Show help
##
## See README.md for Curl invocation; no existing checkout is required
##
## Prerequisites
## - Apple Silicon Mac running macOS, with Xcode command-line tools installed
##   (`xcode-select --install`) and App Store sign-in for the Brewfile's mas apps
## - Exported GPG secret key that can unlock this repository's git-crypt files;
##   public keys in the same directory are imported but never trusted
## - Administrator authentication and GPG passphrases may be requested
##
## Functionality
## - Creates `~/Developer/personal_projects` and clones or reuses its .dotfiles
##   checkout from `https://codeberg.org/pedrusck/.dotfiles.git`, with submodules
## - Ensures Homebrew at `/opt/homebrew` and installs the decryption tools, then
##   imports the supplied keys, ultimately trusts only those carrying secret key
##   material, and unlocks git-crypt
## - Installs the full Brewfile, then runs available `setup.sh` files in profile
##   order, skipping missing scripts
## - Installs EurKEY system-wide, applies profile-dependent keyboard shortcuts
##   unless skipped, and prints remaining manual steps
##
## Reruns reapply configuration and may update installed packages

setopt errexit nounset pipefail

DOTFILES_PATH=$HOME/Developer/personal_projects/.dotfiles
REPOSITORY_URL=https://codeberg.org/pedrusck/.dotfiles.git
PROFILE=development
KEY_DIRECTORY=""
HOMEBREW_EXECUTABLE=/opt/homebrew/bin/brew
GPG_EXECUTABLE=/opt/homebrew/bin/gpg
SKIP_KEYBINDINGS=0
HOMEBREW_BUNDLE_FAILED=0
typeset -a PROFILE_TOOLS=() KEY_FILES=() CONFIGURED_TOOLS=() SKIPPED_TOOLS=()

COLOR_GREEN=$'\e[0;32m'
COLOR_RED=$'\e[0;31m'
COLOR_YELLOW=$'\e[0;33m'
COLOR_RESET=$'\e[0m'

function print_information() { print -r -- "${COLOR_GREEN}$*${COLOR_RESET}" }
function print_warning() { print -r -- "${COLOR_YELLOW}$*${COLOR_RESET}" >&2 }
function print_error() { print -r -- "${COLOR_RED}$*${COLOR_RESET}" >&2 }

function usage() {
	print -r -- "Usage: bootstrap_macos.zsh --key-dir <path> [options]"
	print -r -- ""
	print -r -- "  --profile <name>      Tools to configure (default: development)"
	print -r -- "  --key-dir <path>      Directory holding the GPG key files (*.asc, *.gpg)"
	print -r -- "  --skip-keybindings    Do not touch macOS keyboard shortcuts"
	print -r -- "  -h, --help            Show this help"
}

function parse_arguments() {
	while (( $# )); do
		case $1 in
			--profile|--key-dir)
				(( $# >= 2 )) && [[ -n $2 && $2 != -* ]] || { print_error "$1 requires a value"; exit 1; }
				case $1 in
					--profile) PROFILE=$2 ;;
					--key-dir) KEY_DIRECTORY=$2 ;;
				esac
				shift 2 ;;
			--skip-keybindings) SKIP_KEYBINDINGS=1; shift ;;
			-h|--help) usage; exit 0 ;;
			*) print_error "Unknown argument: $1"; usage; exit 1 ;;
		esac
	done
}

function validate_environment() {
	[[ $(uname -s) == Darwin ]] || { print_error "This script only supports macOS."; exit 1; }
	[[ $(uname -m) == arm64 ]] || { print_error "This script only supports Apple Silicon ($HOMEBREW_EXECUTABLE)."; exit 1; }
	[[ -n $PROFILE && $PROFILE != *[^a-zA-Z0-9_-]* ]] || { print_error "Invalid profile name: $PROFILE"; exit 1; }
	xcode-select -p &>/dev/null || {
		print_error "Install Xcode command line tools with 'xcode-select --install', then rerun."
		exit 1
	}

	[[ -n $KEY_DIRECTORY ]] || { print_error "--key-dir is required (directory with the GPG key files)."; exit 1; }
	[[ -d $KEY_DIRECTORY ]] || { print_error "--key-dir '$KEY_DIRECTORY' does not exist or is not a directory."; exit 1; }
	KEY_DIRECTORY=${KEY_DIRECTORY:A}
	KEY_FILES=( "$KEY_DIRECTORY"/*.asc(N.) "$KEY_DIRECTORY"/*.gpg(N.) )
	(( $#KEY_FILES )) || { print_error "No GPG key files (*.asc, *.gpg) found in $KEY_DIRECTORY"; exit 1; }
}

function prepare_repository() {
	local repository_root origin_url projects_symlink="$HOME/Developer/Personal Projects"
	mkdir -p "${DOTFILES_PATH:h}"
	if [[ -e $DOTFILES_PATH || -L $DOTFILES_PATH ]]; then
		repository_root=$(git -C "$DOTFILES_PATH" rev-parse --show-toplevel 2>/dev/null) \
			|| { print_error "Destination exists but is not a Git checkout: $DOTFILES_PATH"; exit 1; }
		[[ ${repository_root:A} == ${DOTFILES_PATH:A} ]] || {
			print_error "Destination is not a repository root: $DOTFILES_PATH"
			exit 1
		}
		origin_url=$(git -C "$DOTFILES_PATH" remote get-url origin) || { print_error "Existing checkout has no origin."; exit 1; }
		case $origin_url in
			$REPOSITORY_URL|ssh://git@codeberg.org/pedrusck/.dotfiles.git|git@codeberg.org:pedrusck/.dotfiles.git) ;;
			*) print_error "Destination belongs to a different repository: $origin_url"; exit 1 ;;
		esac
		print_information "Using existing checkout: $DOTFILES_PATH"

		# Keep local work intact when resuming an interrupted bootstrap.

		git -C "$DOTFILES_PATH" submodule update --init --recursive
	else
		print_information "Cloning dotfiles to $DOTFILES_PATH"
		git clone --recurse-submodules "$REPOSITORY_URL" "$DOTFILES_PATH"
	fi
	[[ -L $projects_symlink || -e $projects_symlink ]] || ln -s "${DOTFILES_PATH:h}" "$projects_symlink"
}

function load_profile() {
	[[ -f $DOTFILES_PATH/profiles/$PROFILE.sh ]] \
		|| { print_error "Profile '$PROFILE' not found in $DOTFILES_PATH/profiles."; exit 1; }
	local profile_tools_output
	profile_tools_output=$(/bin/sh -eu -c '. "$1"; printf "%s\n" "${PROFILE_TOOLS:-}"' sh "$DOTFILES_PATH/profiles/$PROFILE.sh") \
		|| { print_error "Could not load profile '$PROFILE'."; exit 1; }
	PROFILE_TOOLS=( ${=profile_tools_output} )
	(( $#PROFILE_TOOLS )) || { print_error "Profile '$PROFILE' defines no tools."; exit 1; }
	local tool
	for tool in $PROFILE_TOOLS; do
		[[ $tool != *[^a-zA-Z0-9_-]* ]] || { print_error "Invalid profile tool: $tool"; exit 1; }
	done
	print_information "Profile '$PROFILE' tools: $PROFILE_TOOLS"
}

function ensure_homebrew() {
	local installer homebrew_environment
	if [[ -x $HOMEBREW_EXECUTABLE ]]; then
		print_information "Homebrew already installed"
	else
		print_information "Installing Homebrew"

		installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) \
			|| { print_error "Could not download the Homebrew installer."; exit 1; }
		[[ -n $installer ]] || { print_error "Homebrew installer is empty."; exit 1; }

		# NONINTERACTIVE also disables password prompts inside the installer.

		sudo -v
		NONINTERACTIVE=1 /bin/bash -c "$installer"
		[[ -x $HOMEBREW_EXECUTABLE ]] || { print_error "Homebrew not available at $HOMEBREW_EXECUTABLE after installation."; exit 1; }
	fi
	homebrew_environment=$("$HOMEBREW_EXECUTABLE" shellenv zsh) || { print_error "Could not load the Homebrew environment."; exit 1; }
	eval "$homebrew_environment"
}

function ensure_decrypt_tools() {
	print_information "Ensuring gnupg and git-crypt are installed"
	"$HOMEBREW_EXECUTABLE" install gnupg git-crypt
	[[ -x $GPG_EXECUTABLE ]] || { print_error "GnuPG not available at $GPG_EXECUTABLE after installation."; exit 1; }
}

function import_gpg_keys() {
	local key_file import_output status_marker status_event import_reason fingerprint remaining_fields
	local -aU fingerprints=()
	if [[ -t 0 ]]; then export GPG_TTY=$(tty); fi
	for key_file in $KEY_FILES; do
		print_information "Importing GPG key: ${key_file:t}"
		import_output=$("$GPG_EXECUTABLE" --batch --status-fd 1 --import "$key_file") \
			|| { print_error "Could not import GPG key: $key_file"; exit 1; }

		# IMPORT_OK reason bit 16 marks secret keys, including unchanged imports.
		while read -r status_marker status_event import_reason fingerprint remaining_fields; do
			[[ $status_marker == '[GNUPG:]' && $status_event == IMPORT_OK ]] || continue
			if (( import_reason & 16 )); then
				fingerprints+=( "$fingerprint" )
			fi
		done <<< "$import_output"
	done

	if (( $#fingerprints == 0 )); then
		print_error "No GPG secret keys found in $KEY_DIRECTORY; git-crypt needs the private key."
		exit 1
	fi

	print_information "Marking imported GPG secret keys ultimately trusted"
	for fingerprint in $fingerprints; do
		print -r -- "$fingerprint:6:"
	done | "$GPG_EXECUTABLE" --batch --import-ownertrust
}

function repository_is_locked() {
	local git_directory
	git_directory=$(git -C "$DOTFILES_PATH" rev-parse --absolute-git-dir) \
		|| { print_error "Cannot determine the Git directory for $DOTFILES_PATH"; exit 1; }
	[[ ! -f $git_directory/git-crypt/keys/default ]]
}

function unlock_git_crypt() {
	if repository_is_locked; then
		print_information "Unlocking git-crypt encrypted files"
		git -C "$DOTFILES_PATH" crypt unlock || {
			print_error "git-crypt unlock failed; check that --key-dir contains the repository's private key."
			exit 1
		}
	else
		print_information "Repository already unlocked"
	fi
}

function install_packages() {
	print_information "Updating Homebrew"
	"$HOMEBREW_EXECUTABLE" update --quiet
	print_information "Installing Homebrew packages from Brewfile (this may take a while)"

	caffeinate -i "$HOMEBREW_EXECUTABLE" bundle --file="$DOTFILES_PATH/homebrew/Brewfile" || HOMEBREW_BUNDLE_FAILED=1
}

function run_tool_setups() {
	print_information "Setting up configuration for profile tools"
	local tool
	for tool in $PROFILE_TOOLS; do
		if [[ ! -f $DOTFILES_PATH/$tool/setup.sh ]]; then
			print_information " Skipping $tool (no setup.sh)"
			SKIPPED_TOOLS+=( "$tool" )
			continue
		fi
		print_information " Setting up $tool"
		DOTFILES_PATH=$DOTFILES_PATH /bin/sh "$DOTFILES_PATH/$tool/setup.sh" \
			|| { print_error "Setup failed for profile tool '$tool'."; exit 1; }
		CONFIGURED_TOOLS+=( "$tool" )
	done
}

function install_keyboard_layout() {
	print_information "Installing the EurKEY keyboard layout (system-wide)"

	local source_bundle=$DOTFILES_PATH/eurkey/EurKEY.bundle
	local destination_bundle="/Library/Keyboard Layouts/EurKEY.bundle"
	[[ -f $source_bundle/Contents/Info.plist && -f $source_bundle/Contents/Resources/EurKEY.keylayout ]] \
		|| { print_error "Incomplete EurKEY bundle: $source_bundle"; exit 1; }

	# Replace outright so files removed upstream do not survive; ditto alone merges.
	sudo rm -rf -- "$destination_bundle"
	sudo ditto "$source_bundle" "$destination_bundle" || { print_error "Failed to install EurKEY."; exit 1; }
	print_information "  EurKEY installed to $destination_bundle"
}

function tool_in_profile() {
	(( ${PROFILE_TOOLS[(Ie)$1]} ))
}

function apply_keybindings() {
	if (( SKIP_KEYBINDINGS )); then
		print_information "Skipping keybinding configuration (--skip-keybindings)"
		return
	fi
	if ! tool_in_profile amethyst && ! tool_in_profile neovim; then
		print_information "Neither Amethyst nor Neovim in profile; skipping keybinding configuration"
		return
	fi

	print_information "Configuring macOS keybindings to avoid collisions"

	local -a shortcut_ids=() menu_titles=()
	if tool_in_profile amethyst; then
		# Free Opt+Cmd+D and Opt+Cmd+Space for Amethyst.
		shortcut_ids+=(52 65)
		# Menu titles use the UI language, independently of regional formatting.
		local language
		language=$(defaults export -g - 2>/dev/null | plutil -extract AppleLanguages.0 raw -o - - 2>/dev/null) \
			|| language=unknown
		case ${language:l} in
			en*) menu_titles=("Hide Others" "Minimize All" "Close All") ;;
			de*) menu_titles=("Andere ausblenden" "Alle minimieren" "Alle schließen") ;;
			*) print_warning "Unsupported UI language '$language'; configure Amethyst menu shortcuts manually (macOS_setup_steps.md)." ;;
		esac
		if (( $#menu_titles )); then
			# ^ = Ctrl, ~ = Option, @ = Cmd, $ = Shift; free Opt+Cmd+H/M/W.
			defaults write -g NSUserKeyEquivalents -dict-add "$menu_titles[1]" '^~@$h'
			defaults write -g NSUserKeyEquivalents -dict-add "$menu_titles[2]" '^~@$m'
			defaults write -g NSUserKeyEquivalents -dict-add "$menu_titles[3]" '^~@$w'
		fi
	fi
	if tool_in_profile neovim; then
		# Free Ctrl+Space and Ctrl+Opt+Space for Neovim.
		shortcut_ids+=(60 61)
	fi

	# Disable each shortcut while keeping its key combination, so re-enabling it in
	# System Settings restores the original binding. Missing entries fall back to
	# the macOS defaults; 'defaults' is used throughout to stay consistent with cfprefsd.
	local -A shortcut_default_parameters=(
		52 '100,2,1572864'      # Dock hiding, Opt+Cmd+D
		60 '32,49,262144'       # Previous input source, Ctrl+Space
		61 '32,49,786432'       # Next input source, Ctrl+Opt+Space
		65 '65535,49,1572864'   # Spotlight Finder window, Opt+Cmd+Space
	)
	local shortcut_id shortcut_parameters
	for shortcut_id in $shortcut_ids; do
		shortcut_parameters=$(defaults export com.apple.symbolichotkeys - 2>/dev/null \
			| plutil -extract "AppleSymbolicHotKeys.$shortcut_id.value.parameters" json -o - - 2>/dev/null) \
			|| shortcut_parameters=""
		shortcut_parameters=${shortcut_parameters//[\[\]\" ]/}
		[[ -n $shortcut_parameters ]] || shortcut_parameters=${shortcut_default_parameters[$shortcut_id]:-}
		defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$shortcut_id" \
			"{enabled=0;value={parameters=($shortcut_parameters);type=standard;};}"
	done

	# Reload the affected agents so the changes take effect.
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
	killall Dock &>/dev/null || true
	killall SystemUIServer &>/dev/null || true
}

function print_manual_reminders() {
	print -r --
	print_information "Setup complete!"
	print -r -- " Profile: $PROFILE"
	print -r -- " Tools configured: ${CONFIGURED_TOOLS[*]:-none}"
	print -r -- " Tools skipped:    ${SKIPPED_TOOLS[*]:-none}"

	if (( HOMEBREW_BUNDLE_FAILED )); then
		print -r --
		print_warning "Some Brewfile packages failed to install; rerun to retry:"
		print -r -- "  $HOMEBREW_EXECUTABLE bundle --file=\"$DOTFILES_PATH/homebrew/Brewfile\""
	fi

	print -r --
	print_warning "MANUAL STEP — Enable the EurKEY input source"
	print -r -- "  System Settings > Keyboard > Text Input > Input Sources > Edit... > '+' > EurKEY"
	print -r -- "  A log out or restart may be required before EurKEY appears in the list."
	print -r -- "  See macOS_setup_steps.md for details."

	if tool_in_profile amethyst; then
		print -r --
		print_warning "MANUAL STEP — Enable Switch to Desktop 1–9 for Amethyst"
		print -r -- "  Create desktops in Mission Control, then bind Switch to Desktop 1–9 to Opt+Cmd+1–9."
		print -r -- "  System Settings > Keyboard > Keyboard Shortcuts > Mission Control"
	fi
}

function main() {
	parse_arguments "$@"
	validate_environment
	prepare_repository
	load_profile
	print_information "Setting up macOS with profile '$PROFILE' using Homebrew"
	ensure_homebrew
	ensure_decrypt_tools
	import_gpg_keys
	unlock_git_crypt
	install_packages
	run_tool_setups
	install_keyboard_layout
	apply_keybindings
	print_manual_reminders
}

main "$@"
