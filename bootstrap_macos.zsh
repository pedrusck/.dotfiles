#!/usr/bin/env zsh

## macOS bootstrap for Apple Silicon
##
## Usage
## /bin/zsh -f bootstrap_macos.zsh --key-dir "/Volumes/MY_KEYS" [options]
## --key-dir <path>    Required directory containing GPG exports (.asc, .gpg, .key)
## --profile <name>    Select configurations (default: development)
## --skip-keybindings Leave macOS keyboard shortcuts unchanged
## -h, --help Show help
##
## See README.md for Curl invocation; no existing checkout is required
##
## Prerequisites
## - Apple Silicon Mac running macOS, with Xcode command-line tools installed
## (`xcode-select --install`) and App Store sign-in for the Brewfile's mas apps
## - Exported GPG keypair that can unlock this repository's git-crypt files
## - Administrator authentication and GPG passphrases may be requested
##
## Functionality
## - Creates `~/Developer/personal_projects` and clones or reuses its .dotfiles
## checkout from `https://codeberg.org/pedrusck/.dotfiles.git`, with submodules
## - Ensures Homebrew at `/opt/homebrew`, installs decryption tools
## imports and ultimately trusts the supplied keys and then unlocks git-crypt
## - Installs the full Brewfile, then runs available `setup.sh` files in profile
## order, skipping missing scripts
## - Installs EurKEY system-wide, applies profile-dependent keyboard shortcuts
## unless skipped, and prints remaining manual steps
##
## Reruns reapply configuration and may update installed packages

setopt errexit nounset pipefail

typeset -g DOTFILES_PATH=$HOME/Developer/personal_projects/.dotfiles
typeset -g REPO_URL=https://codeberg.org/pedrusck/.dotfiles.git
typeset -g PROFILE=development
typeset -g KEY_DIR=""
typeset -g BREW_BIN=/opt/homebrew/bin/brew
typeset -gi SKIP_KEYBINDINGS=0
typeset -ga PROFILE_TOOLS=() KEY_FILES=() CONFIGURED_TOOLS=() SKIPPED_TOOLS=()

typeset -g C_GREEN=$'\e[0;32m'
typeset -g C_RED=$'\e[0;31m'
typeset -g C_YELLOW=$'\e[0;33m'
typeset -g C_RESET=$'\e[0m'

function info() { print -r -- "${C_GREEN}$*${C_RESET}" }
function warn() { print -r -- "${C_YELLOW}$*${C_RESET}" >&2 }
function error() { print -r -- "${C_RED}$*${C_RESET}" >&2 }

function usage() {
    print -r -- "Usage: bootstrap_macos.zsh --key-dir <path> [options]

  --profile <name> Tools to configure (default: development; all Brewfile packages are installed)
  --key-dir <path> Directory holding the GPG key files (*.asc,*.gpg, *.key)
  --skip-keybindings Do not touch macOS keyboard shortcuts
  -h, --help Show this help"
}

function parse_args() {
    while (( $# )); do
        case $1 in
            --profile|--key-dir)
                (( $# >= 2 )) && [[ -n $2 && $2 != -* ]] || { error "$1 requires a value"; exit 1; }
                case $1 in
                    --profile) PROFILE=$2 ;;
                    --key-dir) KEY_DIR=$2 ;;
                esac
                shift 2 ;;
            --skip-keybindings) SKIP_KEYBINDINGS=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) error "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done
}

function validate_env() {
    [[ $(uname -s) == Darwin ]] || { error "This script only supports macOS."; exit 1; }
    [[ -n $PROFILE && $PROFILE != *[^a-zA-Z0-9_-]* ]] || { error "Invalid profile name: $PROFILE"; exit 1; }
    xcode-select -p &>/dev/null || {
        error "Install Xcode command line tools with 'xcode-select --install', then rerun."
        exit 1
    }

	[[ -n $KEY_DIR ]] || { error "--key-dir is required (directory with the GPG key files)."; exit 1; }
	[[ -d $KEY_DIR ]] || { error "--key-dir '$KEY_DIR' does not exist or is not a directory."; exit 1; }
	KEY_DIR=${KEY_DIR:A}
	KEY_FILES=( "$KEY_DIR"/*.asc(N.) "$KEY_DIR"/*.gpg(N.) "$KEY_DIR"/*.key(N.) )
	(( $#KEY_FILES )) || { error "No GPG key files (*.asc, *.gpg, *.key) found in $KEY_DIR"; exit 1; }
}

function prepare_repository() {
    local root origin link="$HOME/Developer/Personal Projects"
    mkdir -p "${DOTFILES_PATH:h}"
    if [[ -e $DOTFILES_PATH || -L $DOTFILES_PATH ]]; then
        root=$(git -C "$DOTFILES_PATH" rev-parse --show-toplevel 2>/dev/null) \
            || { error "Destination exists but is not a Git checkout: $DOTFILES_PATH"; exit 1; }
        [[ ${root:A} == ${DOTFILES_PATH:A} ]] || {
            error "Destination is not a repository root: $DOTFILES_PATH"
            exit 1
        }
        origin=$(git -C "$DOTFILES_PATH" remote get-url origin) || { error "Existing checkout has no origin."; exit 1; }
        case $origin in
            $REPO_URL|ssh://git@codeberg.org/pedrusck/.dotfiles.git|git@codeberg.org:pedrusck/.dotfiles.git) ;;
            *) error "Destination belongs to a different repository: $origin"; exit 1 ;;
        esac
        info "Using existing checkout: $DOTFILES_PATH"

        # Keep local work intact when resuming an interrupted bootstrap.

        git -C "$DOTFILES_PATH" submodule update --init --recursive
    else
        info "Cloning dotfiles to $DOTFILES_PATH"
        git clone --recurse-submodules "$REPO_URL" "$DOTFILES_PATH"
    fi
    [[ -L $link || -e $link ]] || ln -s "${DOTFILES_PATH:h}" "$link"
}

function load_profile() {
    [[ -f $DOTFILES_PATH/profiles/$PROFILE.sh ]] \
        || { error "Profile '$PROFILE' not found in $DOTFILES_PATH/profiles."; exit 1; }
    local tools
    tools=$(/bin/sh -eu -c '. "$1"; printf "%s\n" "${PROFILE_TOOLS:-}"' sh "$DOTFILES_PATH/profiles/$PROFILE.sh") \
        || { error "Could not load profile '$PROFILE'."; exit 1; }
    PROFILE_TOOLS=( ${=tools} )
    (( $#PROFILE_TOOLS )) || { error "Profile '$PROFILE' defines no tools."; exit 1; }
    local tool
    for tool in $PROFILE_TOOLS; do
        [[ -n $tool && $tool != *[^a-zA-Z0-9_-]* ]] || { error "Invalid profile tool: $tool"; exit 1; }
    done
    info "Profile '$PROFILE' tools: $PROFILE_TOOLS"
}

function ensure_homebrew() {
    local installer brew_env
    if [[ -x $BREW_BIN ]]; then
        info "Homebrew already installed"
    else
        info "Installing Homebrew"
        installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) \
            || { error "Could not download the Homebrew installer."; exit 1; }
        [[ -n $installer ]] || { error "Homebrew installer is empty."; exit 1; }

        # NONINTERACTIVE also disables password prompts inside the installer.

        sudo -v
        NONINTERACTIVE=1 /bin/bash -c "$installer"
        [[ -x $BREW_BIN ]] || { error "Homebrew not available at $BREW_BIN after installation."; exit 1; }
    fi
    brew_env=$("$BREW_BIN" shellenv zsh) || { error "Could not load the Homebrew environment."; exit 1; }
    eval "$brew_env"
}

function ensure_decrypt_tools() {
    info "Ensuring gnupg and git-crypt are installed"
    "$BREW_BIN" install gnupg git-crypt
}

function import_gpg_keys() {
    local key_file import_output marker event reason fingerprint rest
    local -aU fingerprints=()
    if [[ -t 0 ]]; then export GPG_TTY=$(tty); fi
    for key_file in $KEY_FILES; do
        info "Importing GPG key: ${key_file:t}"
        import_output=$(gpg --batch --status-fd 1 --import "$key_file") \
            || { error "Could not import GPG key: $key_file"; exit 1; }
        while read -r marker event reason fingerprint rest; do
            if [[ $marker == '[GNUPG:]' && $event == IMPORT_OK && -n $fingerprint ]]; then
                fingerprints+=( "$fingerprint" )
            fi
        done <<< "$import_output"
    done
    (( $#fingerprints )) || { error "GPG reported no successfully imported keys."; exit 1; }

    # IMPORT_OK includes unchanged imports, without selecting unrelated keys in the keyring.

    info "Marking imported GPG keys ultimately trusted"
    for fingerprint in $fingerprints; do
        print -r -- "$fingerprint:6:"
    done | gpg --batch --import-ownertrust
}

function repo_is_locked() {

    # Inspect the magic header to avoid unlocking an already decrypted checkout.

    # Zsh preserves NUL bytes in command substitutions.

    local probe=$DOTFILES_PATH/git/additional_configuration/configuration.secret.gitconfig header
    [[ -f $probe && -r $probe && -s $probe ]] || { error "Cannot inspect git-crypt probe: $probe"; exit 1; }
    header=$(head -c 10 -- "$probe") || { error "Cannot read git-crypt probe: $probe"; exit 1; }
    [[ $header == $'\0GITCRYPT\0' ]]
}

function unlock_git_crypt() {
    if repo_is_locked; then
        info "Unlocking git-crypt encrypted files"
        git -C "$DOTFILES_PATH" crypt unlock || {
            error "git-crypt unlock failed; check that --key-dir contains the repository's private key."
            exit 1
        }
        if repo_is_locked; then
            error "Repository is still encrypted after git-crypt unlock."
            exit 1
        fi
    else
        info "Repository already unlocked"
    fi
}

function install_packages() {
    info "Updating Homebrew"
    "$BREW_BIN" update --quiet
    info "Installing Homebrew packages from Brewfile (this may take a while)"
    caffeinate -i "$BREW_BIN" bundle --file="$DOTFILES_PATH/homebrew/Brewfile"
}

function run_tool_setups() {
    info "Setting up configuration for profile tools"
    local tool
    for tool in $PROFILE_TOOLS; do
        if [[ ! -f $DOTFILES_PATH/$tool/setup.sh ]]; then
            info " Skipping $tool (no setup.sh)"
            SKIPPED_TOOLS+=( "$tool" )
            continue
        fi
        info " Setting up $tool"
        DOTFILES_PATH=$DOTFILES_PATH /bin/sh "$DOTFILES_PATH/$tool/setup.sh" \
            || { error "Setup failed for profile tool '$tool'."; exit 1; }
        CONFIGURED_TOOLS+=( "$tool" )
    done
}

function install_keyboard_layout() {
    info "Installing the EurKEY keyboard layout (system-wide)"

	local src=$DOTFILES_PATH/eurkey/EurKEY.bundle
	local dest="/Library/Keyboard Layouts/EurKEY.bundle"
	[[ -f $src/Contents/Info.plist && -f $src/Contents/Resources/EurKEY.keylayout ]] \
		|| { error "Incomplete EurKEY bundle: $src"; exit 1; }
	plutil -lint "$src/Contents/Info.plist" >/dev/null || { error "Invalid EurKEY bundle: $src"; exit 1; }

	# Avoid another sudo prompt when the installed layout already matches.
	if [[ -d $dest ]] && diff -rq "$src" "$dest" &>/dev/null; then
		info "  EurKEY already installed and up to date"
		return 0
	fi

	# Replacing the complete bundle prevents stale files from surviving an update.
	local staging
	sudo mkdir -p "${dest:h}"
	staging=$(sudo mktemp -d "${dest:h}/.eurkey.XXXXXX")
	sudo ditto "$src" "$staging/EurKEY.bundle" \
		&& sudo rm -rf -- "$dest" \
		&& sudo mv "$staging/EurKEY.bundle" "$dest" || {
		sudo rm -rf -- "$staging"
		error "Failed to install EurKEY."
		exit 1
	}
	sudo rmdir "$staging"
	info "  EurKEY installed to $dest"
}

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

	local -a ids=() titles=()
	if tool_in_profile amethyst; then
		# Free Opt+Cmd+D and Opt+Cmd+Space for Amethyst.
		ids+=(52 65)
		# Menu titles use the UI language, independently of regional formatting.
		local language
		language=$(defaults export -g - 2>/dev/null | plutil -extract AppleLanguages.0 raw -o - - 2>/dev/null) \
			|| language=unknown
		case ${language:l} in
			en*) titles=("Hide Others" "Minimize All" "Close All") ;;
			de*) titles=("Andere ausblenden" "Alle minimieren" "Alle schließen") ;;
			*) warn "Unsupported UI language '$language'; configure Amethyst menu shortcuts manually (macOS_setup_steps.md)." ;;
		esac
		if (( $#titles )); then
			# ^ = Ctrl, ~ = Option, @ = Cmd, $ = Shift; free Opt+Cmd+H/M/W.
			defaults write -g NSUserKeyEquivalents -dict-add "$titles[1]" '^~@$h'
			defaults write -g NSUserKeyEquivalents -dict-add "$titles[2]" '^~@$m'
			defaults write -g NSUserKeyEquivalents -dict-add "$titles[3]" '^~@$w'
		fi
	fi
	if tool_in_profile neovim; then
		# Free Ctrl+Space and Ctrl+Opt+Space for Neovim.
		ids+=(60 61)
	fi

	local plist=$HOME/Library/Preferences/com.apple.symbolichotkeys.plist
	local id
	for id in $ids; do
		/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:${id}:enabled false" "$plist" 2>/dev/null \
			|| defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
				'{enabled=0;value={parameters=(65535,65535,0);type=standard;};}'
	done

	# Reload the affected agents so the changes take effect.
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
	killall Dock &>/dev/null || true
	killall SystemUIServer &>/dev/null || true
}

function print_manual_reminders() {
    print -r --
    info "Setup complete!"
    print -r -- " Profile: $PROFILE"
    print -r -- " Tools configured: ${CONFIGURED_TOOLS[*]:-none}"
    print -r -- " Tools skipped:    ${SKIPPED_TOOLS[*]:-none}"

	print -r --
	warn "MANUAL STEP — Enable the EurKEY input source"
	print -r -- "  System Settings > Keyboard > Text Input > Input Sources > Edit... > '+' > EurKEY
  A log out or restart may be required before EurKEY appears in the list.
  See macOS_setup_steps.md for details."

	if tool_in_profile amethyst; then
		print -r --
		warn "MANUAL STEP — Enable Switch to Desktop 1–9 for Amethyst"
		print -r -- "  Create desktops in Mission Control, then bind Switch to Desktop 1–9 to Opt+Cmd+1–9.
  System Settings > Keyboard > Keyboard Shortcuts > Mission Control"
    fi
}

function main() {
    parse_args "$@"
    validate_env
    prepare_repository
    load_profile
    info "Setting up macOS with profile '$PROFILE' using Homebrew"
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
