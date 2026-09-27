# Dotfiles

To my future self,

## for macOS

On an Apple Silicon Mac, complete these prerequisites:

1. **Install the Xcode command line tools** (provides `git` for cloning):

   ```sh
   xcode-select --install
   ```

2. **Sign in to the App Store** so Homebrew can install the `mas` apps in the Brewfile.

Insert the pendrive holding your GPG keypair, then run the
[bootstrap script](./bootstrap_macos.zsh) from any directory:

```sh
bootstrap=$(curl -fsSL \
  https://codeberg.org/pedrusck/.dotfiles/raw/branch/main/bootstrap_macos.zsh) &&
  /bin/zsh -f -c "$bootstrap" bootstrap_macos.zsh \
    --key-dir "/Volumes/MY_KEYS" --profile development
```

Replace `/Volumes/MY_KEYS` with the directory containing your `.asc`, `.gpg`, or
`.key` files. Downloading before execution preserves terminal input for sudo
and GPG passphrase prompts and prevents execution after a failed download.

The script creates `$HOME/Developer/personal_projects` and clones
`https://codeberg.org/pedrusck/.dotfiles.git` into its `.dotfiles` directory,
including all submodules. An existing checkout at that destination is reused
without pulling or resetting local work; missing submodules are initialized.

It installs Homebrew at `/opt/homebrew` without an acceptance prompt, imports
the supplied GPG keys and marks only those keys ultimately trusted, unlocks
git-crypt, and installs the Brewfile packages. Administrator authentication and
GPG passphrases may still be required. Unrelated keys retain their ownertrust;
keys supplied again on a rerun are included even if their import is unchanged.

After installation, it runs the available tool setup scripts in profile order,
installs the EurKEY keyboard layout system-wide, and sets macOS keybindings that
would otherwise collide with Amethyst/Neovim. The `development` profile includes
`browserpass/setup.sh`, which registers native-messaging hosts for installed
Firefox/Floorp/Helium browsers.

Use `--profile <name>` to choose which tools are configured; every profile still
installs the full `homebrew/Brewfile`. Tools without a `<tool>/setup.sh` are
reported as skipped. Use `--skip-keybindings` to leave keyboard
shortcuts alone. Menu shortcut remapping supports English and German UI languages;
other languages require manual setup as described in `macOS_setup_steps.md`.

Rerunning reapplies configuration and can update installed packages. You can
also run the cloned script directly:

```sh
/bin/zsh -f "$HOME/Developer/personal_projects/.dotfiles/bootstrap_macos.zsh" \
  --key-dir "/Volumes/MY_KEYS"
```

When it finishes it prints the remaining manual steps (enable the EurKEY input
source, and Switch to Desktop 1–9 for Amethyst). Afterwards, follow the rest of
the steps in the [list](./macOS_setup_steps.md).

## Encrypted files

Files matching `*.secret` and `*.secret.*` are encrypted with
[git-crypt](https://github.com/AGWA/git-crypt) using a GPG key. They appear as
plaintext in the working tree but are stored encrypted in git.

On a new machine:

1. Import the GPG private key: `gpg --import <key-file>`
2. Install git-crypt: `brew install git-crypt`
3. Unlock the repo: `git-crypt unlock`

`bootstrap_macos.zsh` imports the keys supplied through `--key-dir`, marks those
keys ultimately trusted, and unlocks the repository before installing the
Brewfile packages. Ultimate ownertrust is applied to these imported keys for
subsequent GPG use; git-crypt decryption itself does not require it.

Greetings from the past

## for Raspberry Pi

- Install git `sudo apt install git -y`

- Clone this repository with
`git clone https://codeberg.org/petrusck/.dotfiles.git`

- Run the initialization [script](./bootstrap_raspotify.sh) with `./bootstrap_raspotify.sh`.
