#!/usr/bin/env zsh

### Master setup script for macOS (Homebrew) ###
#
# Usage:
#   ./bootstrap.zsh [--profile <name>] --key-dir <path> [--skip-keybindings]
#
# Prerequisites (see README.md):
#   1. Install Xcode command line tools:  xcode-select --install
#   2. Sign in to the App Store (needed for the `mas` apps in the Brewfile)
#   3. Clone this repository and `cd` into it
#
# What it does:
#   - Installs Homebrew and the packages listed in homebrew/Brewfile
#   - Imports the GPG keypair from --key-dir, marks it ultimately trusted,
#     and unlocks the git-crypt encrypted files
#   - Registers Browserpass native-messaging hosts for Firefox/Helium (if installed)
#   - Restores browser bookmarks for Helium/Floorp from browser_bookmarks/ (if present)
#   - Symlinks the configuration of every tool in the selected profile
#   - Creates the projects directory and updates TeX Live
#   - Installs the EurKEY keyboard layout (git submodule) system-wide
#   - Configures macOS keybindings so they do not collide with Amethyst/Neovim
#
# Every phase is idempotent: re-running the script is safe.

setopt errexit nounset pipefail warn_create_global

### Script-level state (declared here so functions never create globals) ###

typeset -g DOTFILES_PATH=${0:A:h}
typeset -g SCRIPT_NAME=${0:t}
typeset -g PROFILE=""
typeset -g KEY_DIR=""
typeset -g SKIP_KEYBINDINGS=0
typeset -g GECKO_BOOKMARKS_STAGED=0
typeset -ga PROFILE_TOOLS

typeset -g C_GREEN=$'\e[0;32m'
typeset -g C_RED=$'\e[0;31m'
typeset -g C_YELLOW=$'\e[0;33m'
typeset -g C_RESET=$'\e[0m'

### Output helpers ###

function info()  { print -r -- "${C_GREEN}$*${C_RESET}" }
function warn()  { print -r -- "${C_YELLOW}$*${C_RESET}" }
function error() { print -r -- "${C_RED}$*${C_RESET}" >&2 }

function usage() {
	print -r -- "Usage: $SCRIPT_NAME [--profile <name>] --key-dir <path> [--skip-keybindings]"
	print -r --
	print -r -- "  --profile            Profile to install (default: development)"
	print -r -- "  --key-dir            Directory holding the GPG key files (*.asc, *.gpg, *.key)"
	print -r -- "  --skip-keybindings   Do not touch macOS keyboard shortcuts"
}

### Argument parsing ###

function parse_args() {
	while (( $# )); do
		case $1 in
			--profile) PROFILE=$2; shift 2 ;;
			--key-dir) KEY_DIR=$2; shift 2 ;;
			--skip-keybindings) SKIP_KEYBINDINGS=1; shift ;;
			-h|--help) usage; exit 0 ;;
			*) error "Unknown argument: $1"; usage; exit 1 ;;
		esac
	done
	: ${PROFILE:=development}
}

### Environment validation ###

function validate_env() {
	[[ $(uname -s) == Darwin ]] || { error "This script only supports macOS."; exit 1 }

	[[ -f $DOTFILES_PATH/profiles/$PROFILE.sh ]] \
		|| { error "Profile '$PROFILE' not found in $DOTFILES_PATH/profiles."; exit 1 }

	[[ -n $KEY_DIR ]] || { error "--key-dir is required (directory with the GPG key files)."; exit 1 }
	[[ -d $KEY_DIR ]] || { error "--key-dir '$KEY_DIR' does not exist or is not a directory."; exit 1 }
}

### Profile loading ###

function load_profile() {
	source "$DOTFILES_PATH/profiles/$PROFILE.sh"
	(( $#PROFILE_TOOLS )) || { error "Profile '$PROFILE' defines no tools."; exit 1 }
	info "Profile '$PROFILE' tools: $PROFILE_TOOLS"
}

### Xcode command line tools ###

function ensure_xcode_clt() {
	if xcode-select -p &>/dev/null; then
		info "Xcode command line tools already installed"
		return
	fi
	info "Installing Xcode command line tools"
	xcode-select --install
	until xcode-select -p &>/dev/null; do sleep 5; done
}

### Homebrew ###

function load_brew_env() {
	# brew shellenv exports HOMEBREW_* variables; they are required for the rest
	# of the script but should not trip warn_create_global — scope the option.
	setopt local_options no_warn_create_global
	local brew_bin
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		[[ -x $brew_bin ]] || continue
		eval "$($brew_bin shellenv)"
		return
	done
}

function ensure_homebrew() {
	if command -v brew &>/dev/null; then
		info "Homebrew already installed"
	else
		info "Installing Homebrew"
		# NOTE: Fetches the installer from HEAD; Homebrew does not publish
		# per-release checksums. This is the officially recommended method.
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	load_brew_env
	command -v brew &>/dev/null || { error "Homebrew not available after installation."; exit 1 }
}

### Decryption tooling ###

function ensure_decrypt_tools() {
	info "Ensuring gnupg and git-crypt are installed"
	brew install gnupg git-crypt
}

### GPG import + trust ###

function import_gpg_keys() {
	local -a key_files
	key_files=( $KEY_DIR/*.asc(N) $KEY_DIR/*.gpg(N) $KEY_DIR/*.key(N) )
	(( $#key_files )) || { error "No GPG key files (*.asc, *.gpg, *.key) found in $KEY_DIR"; exit 1 }

	local key_file
	for key_file in $key_files; do
		info "Importing GPG key: ${key_file:t}"
		gpg --batch --import "$key_file"
	done

	# Mark every primary secret key we now hold as ultimately trusted.
	# gpg --with-colons prints a `sec:` record followed by its `fpr:` record.
	local line want_fpr=0 fpr
	local -a parts
	for line in ${(f)"$(gpg --list-secret-keys --with-colons 2>/dev/null)"}; do
		case $line in
			sec:*) want_fpr=1 ;;
			fpr:*)
				if (( want_fpr )); then
					parts=( "${(@s.:.)line}" )
					fpr=$parts[10]
					[[ -n $fpr ]] && print -r -- "${fpr}:6:" | gpg --import-ownertrust
					want_fpr=0
				fi
				;;
		esac
	done
}

### git-crypt unlock (idempotent) ###

function repo_is_locked() {
	# A git-crypt encrypted blob begins with the magic header "\0GITCRYPT\0".
	# Command substitution strips the leading NUL, so match GITCRYPT loosely.
	local probe=$DOTFILES_PATH/git/additional_configuration/configuration.secret.gitconfig
	[[ -f $probe ]] || return 1
	[[ "$(head -c 10 -- "$probe" 2>/dev/null)" == *GITCRYPT* ]]
}

function unlock_git_crypt() {
	if repo_is_locked; then
		info "Unlocking git-crypt encrypted files"
		git -C "$DOTFILES_PATH" crypt unlock
	else
		info "Repository already unlocked"
	fi
}

### Homebrew packages ###

function install_packages() {
	#info "Updating Homebrew"
	#brew update --force --quiet
	#info "Installing Homebrew packages from Brewfile (this may take a while)"
	#caffeinate -i brew bundle --file="$DOTFILES_PATH/homebrew/Brewfile"
}

### Browserpass native messaging hosts ###

function configure_browserpass() {
	local prefix
	prefix=$(brew --prefix browserpass 2>/dev/null) || { info "browserpass not installed, skipping native messaging host setup"; return 0 }
	[[ -d $prefix ]] || { info "browserpass not installed, skipping native messaging host setup"; return 0 }

	info "Configuring Browserpass native messaging hosts"

	# Firefox
	if [[ -d "/Applications/Firefox.app" ]]; then
		local firefox_host="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/com.github.browserpass.native.json"
		if [[ -f $firefox_host ]]; then
			info "  Browserpass Firefox host already registered"
		else
			info "  Registering Browserpass host for Firefox"
			PREFIX="$prefix" make hosts-firefox-user -f "$prefix/lib/browserpass/Makefile" \
				|| warn "  Failed to register Browserpass host for Firefox"
		fi
	else
		info "  Firefox not installed, skipping Browserpass Firefox host"
	fi

	# Helium
	if [[ -d "/Applications/Helium.app" ]]; then
		local helium_dir="$HOME/Library/Application Support/net.imput.helium/NativeMessagingHosts"
		local helium_host="$helium_dir/com.github.browserpass.native.json"
		local helium_src="$prefix/lib/browserpass/hosts/chromium/com.github.browserpass.native.json"
		if [[ -L $helium_host && "$(readlink "$helium_host")" == "$helium_src" ]]; then
			info "  Browserpass Helium host already registered"
		else
			info "  Registering Browserpass host for Helium"
			mkdir -p "$helium_dir" \
				&& ln -sfv "$helium_src" "$helium_host" \
				|| warn "  Failed to register Browserpass host for Helium"
		fi
	else
		info "  Helium not installed, skipping Browserpass Helium host"
	fi
}

### Browser bookmarks restore ###

function restore_browser_bookmarks() {
	local bookmarks_dir=$DOTFILES_PATH/browser_bookmarks
	[[ -d $bookmarks_dir ]] || { info "browser_bookmarks directory not found, skipping bookmarks restore"; return 0 }

	# Chromium-based (Helium)
	local chromium_script=$bookmarks_dir/restore_chromium_based_browser_bookmarks.zsh
	local -a chromium_snapshots=($bookmarks_dir/chromium_based_browser_bookmarks_*.secret.json(N))
	if [[ ! -f $chromium_script ]]; then
		info "  restore_chromium_based_browser_bookmarks.zsh not found, skipping"
	elif (( ! $#chromium_snapshots )); then
		info "  No Chromium bookmarks snapshot found, skipping"
	elif [[ ! -d "/Applications/Helium.app" ]]; then
		info "  Helium not installed, skipping Chromium bookmarks restore"
	else
		info "  Restoring Chromium-based (Helium) bookmarks"
		zsh "$chromium_script" "$bookmarks_dir" || warn "  Failed to restore Chromium-based bookmarks"
	fi

	# Gecko-based (Floorp)
	local gecko_script=$bookmarks_dir/restore_gecko_based_browser_bookmarks.zsh
	local -a gecko_snapshots=($bookmarks_dir/gecko_based_browser_bookmarks_*.secret.jsonlz4(N))
	if [[ ! -f $gecko_script ]]; then
		info "  restore_gecko_based_browser_bookmarks.zsh not found, skipping"
	elif (( ! $#gecko_snapshots )); then
		info "  No Gecko bookmarks snapshot found, skipping"
	elif [[ ! -d "$HOME/Library/Application Support/Floorp" ]]; then
		info "  Floorp not installed, skipping Gecko bookmarks restore"
	else
		info "  Staging Gecko-based (Floorp) bookmarks (manual step required to finish)"
		if zsh "$gecko_script" "$bookmarks_dir"; then
			GECKO_BOOKMARKS_STAGED=1
		else
			warn "  Failed to stage Gecko-based bookmarks"
		fi
	fi
}

### Tool configuration ###

function run_tool_setups() {
	info "Setting up configuration for profile tools"
	local tool setup_script
	for tool in $PROFILE_TOOLS; do
		setup_script=$DOTFILES_PATH/$tool/setup.sh
		if [[ -f $setup_script ]]; then
			info "  Setting up $tool"
			DOTFILES_PATH=$DOTFILES_PATH zsh "$setup_script"
		else
			warn "  No setup.sh found for '$tool', skipping"
		fi
	done
}

### Projects directories ###

function create_projects_dirs() {
	info "Creating projects directories"
	local target=$HOME/Developer/personal_projects
	local link="$HOME/Developer/Personal Projects"
	[[ -d $target ]] || mkdir -p "$target"
	[[ -L $link || -e $link ]] || ln -s "$target" "$link"
}

### TeX Live ###

function update_texlive() {
	command -v tlmgr &>/dev/null || return 0
	info "Updating TeX Live packages"
	sudo tlmgr update --self --all --reinstall-forcibly-removed || warn "TeX Live update failed"
}

### EurKEY keyboard layout (system-wide, from git submodule) ###

function install_keyboard_layout() {
	info "Installing the EurKEY keyboard layout (system-wide)"

	# Ensure the submodule is checked out (idempotent).
	git -C "$DOTFILES_PATH" submodule update --init --recursive eurkey

	local src=$DOTFILES_PATH/
	local dest="/Library/Keyboard Layouts/EurKEY.bundle"

	[[ -d $src ]] || { warn "  EurKEY.bundle not found at $src, skipping"; return 0 }

	# Idempotent: only touch /Library (sudo) when the layout is missing or changed.
	if [[ -d $dest ]] && diff -rq "$src" "$dest" &>/dev/null; then
		info "  EurKEY already installed and up to date"
		return 0
	fi

	#sudo mkdir -p "/Library/Keyboard Layouts"
	#sudo rm -rf "$dest"
	sudo ditto "$src" "$dest"   # native macOS, bundle-safe copy
	info "  EurKEY installed to $dest"
}

### Keybinding collision avoidance ###

function tool_in_profile() {
	(( ${PROFILE_TOOLS[(Ie)$1]} ))
}

function apply_keybindings() {
	if (( SKIP_KEYBINDINGS )); then
		info "Skipping keybinding configuration (--skip-keybindings)"
		return
	fi
	if ! tool_in_profile amethyst && ! tool_in_profile neovim; then
		info "Neither Amethyst nor Neovim in profile; skipping keybinding configuration"
		return
	fi

	info "Configuring macOS keybindings to avoid collisions"

	# App Shortcut menu titles depend on the UI language; auto-detect EN/DE.
	local locale
	locale=$(defaults read -g AppleLocale 2>/dev/null) || locale=en_US
	[[ -n $locale ]] || locale=en_US

	local hide_others minimize_all close_all
	if [[ ${locale:l} == de* ]]; then
		hide_others="Andere ausblenden"
		minimize_all="Alle minimieren"
		close_all="Alle schließen"
	else
		hide_others="Hide Others"
		minimize_all="Minimize All"
		close_all="Close All"
	fi

	# App Shortcuts (All Applications): remap to a dummy Ctrl+Opt+Cmd+Shift+<key>
	# so Amethyst can use Opt+Cmd+H / Opt+Cmd+M / Opt+Cmd+W.
	# ^ = Ctrl, ~ = Option, @ = Cmd, $ = Shift.
	defaults write -g NSUserKeyEquivalents -dict-add "$hide_others"  '^~@$h'
	defaults write -g NSUserKeyEquivalents -dict-add "$minimize_all" '^~@$m'
	defaults write -g NSUserKeyEquivalents -dict-add "$close_all"    '^~@$w'

	# Disable colliding system symbolic hotkeys:
	#   52 = Turn Dock Hiding On/Off       (frees Opt+Cmd+D)
	#   65 = Show Finder search window     (frees Opt+Cmd+Space)
	#   60 = Select the previous input source (frees Ctrl+Space)
	#   61 = Select next source in input menu (frees Ctrl+Opt+Space)
	local plist=$HOME/Library/Preferences/com.apple.symbolichotkeys.plist
	local id
	for id in 52 65 60 61; do
		/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:$id:enabled false" "$plist" 2>/dev/null \
			|| defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
				'{enabled=0;value={parameters=(65535,65535,0);type=standard;};}'
	done

	# Reload the affected agents so the changes take effect.
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
	killall Dock &>/dev/null || true
	killall SystemUIServer &>/dev/null || true
}

### Final reminders ###

function print_manual_reminders() {
	print -r --
	info "Setup complete!"
	print -r -- "  Profile:          $PROFILE"
	print -r -- "  Tools configured: $PROFILE_TOOLS"

	print -r --
	warn "MANUAL STEP — Enable the EurKEY input source"
	print -r -- "  The EurKEY layout is installed, but macOS will not activate it automatically:"
	print -r -- "  1. System Settings > Keyboard > Text Input > Input Sources > Edit... > '+'"
	print -r -- "  2. Add 'EurKEY' (listed under English / EurKEY) and remove unwanted layouts."
	print -r -- "  A log out or restart may be required before EurKEY appears in the list."
	print -r -- "  See macOS_setup_steps.md for details."

	if (( GECKO_BOOKMARKS_STAGED )); then
		print -r --
		warn "MANUAL STEP — Finish restoring Floorp bookmarks"
		print -r -- "  A bookmarks snapshot was staged into Floorp's bookmarkbackups folder."
		print -r -- "  Bookmarks > Manage Bookmarks > Import and Backup > Restore > pick today's date > confirm."
	fi
}

### Entry point ###

function main() {
	parse_args "$@"
	validate_env
	load_profile
	info "Setting up macOS with profile '$PROFILE' using Homebrew"
	ensure_xcode_clt
	ensure_homebrew
	ensure_decrypt_tools
	import_gpg_keys
	unlock_git_crypt
	install_packages
	configure_browserpass
	restore_browser_bookmarks
	run_tool_setups
	create_projects_dirs
	install_keyboard_layout
	update_texlive
	apply_keybindings
	print_manual_reminders
}

main "$@"
