# Dotfiles

To my future self,

## for macOS

Apple Silicon is required; the script refuses to run on Intel because it expects
Homebrew at `/opt/homebrew`. Complete these prerequisites:

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

Replace `/Volumes/MY_KEYS` with the directory containing your `.asc` or `.gpg`
files. Downloading before execution preserves terminal input for sudo
and GPG passphrase prompts and prevents execution after a failed download.

The script creates `$HOME/Developer/personal_projects` and clones
`https://codeberg.org/pedrusck/.dotfiles.git` into its `.dotfiles` directory,
including all submodules. An existing checkout at that destination is reused
without pulling or resetting local work; missing submodules are initialized.
The clone is verified to come from the expected origin URL, but its commits are
not signature-verified.

It installs Homebrew at `/opt/homebrew` without an acceptance prompt, imports
the supplied GPG keys, unlocks git-crypt, and installs the Brewfile packages.
Administrator authentication and GPG passphrases may still be required.

Brewfile failures are not fatal: a package that cannot be installed (commonly a
`mas` app needing a different App Store account or region) is reported in the
closing summary with a command to retry, so the remaining setup still runs.

Ultimate ownertrust is granted **only to imported keys that carry secret key
material**. Public keys that happen to share the directory are imported and
reported, but never become trust roots. Unrelated keys already in the keyring
retain their ownertrust, and keys supplied again on a rerun are included even
if their import is unchanged.

Homebrew is installed by fetching upstream's official `install.sh` from the
moving `HEAD` ref and executing it unverified while sudo is pre-authorized.
This is Homebrew's documented installation method and is accepted deliberately;
it does mean a compromised upstream would gain root on a fresh machine.

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

### Browserpass

The development profile runs Browserpass setup automatically. To rerun it after
installing a browser or repairing Browserpass, from the repository root:

```sh
sh browserpass/setup.sh
```

Setup detects Firefox, Floorp, and Helium in `/Applications` and
`~/Applications`, then links the installed Browserpass host manifests into the
per-user native-messaging directories:

- **Firefox/Floorp:** the Firefox manifest goes under
  `~/Library/Application Support/Mozilla/NativeMessagingHosts/`.
- **Helium:** the Chromium manifest goes under
  `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`.
  Helium searches this Chrome-compatible location; Chrome need not be installed.

Each directory receives a `com.github.browserpass.native.json` symlink through
Homebrew's stable Browserpass prefix. Firefox and Floorp share one registration.
Helium searches its own `net.imput.helium/NativeMessagingHosts/` directory first.
An existing manifest there is accepted if it resolves to the same Homebrew source;
otherwise setup asks you to move it aside so the Chrome registration can be used.
Setup skips successfully when no supported browser, Homebrew, or Browserpass is
installed. It checks each manifest's executable and verifies the resulting link.
Rerunning refreshes registrations; conflicting files, directories, and symlinks
to directories are preserved and reported as errors. A missing Chromium manifest
is a package problem: setup reports it rather than creating a broken Helium link.

Install the Browserpass extension in each browser profile you use:

- [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/browserpass-ce/)
  for Floorp and Firefox.
- [Chrome Web Store](https://chromewebstore.google.com/detail/browserpass/naepdomgkenhinolocfifgehidddafch)
  for Helium.

If setup reports a missing or invalid manifest, or a missing native executable,
try reinstalling the package and rerun setup:

```sh
brew reinstall browserpass
sh browserpass/setup.sh
```

If the manifest remains missing after reinstalling, investigate the Browserpass
Homebrew formula; setup cannot generate a packaged host manifest.

Open the extension in each browser to check host discovery. If entries appear
but decryption or autofill fails, follow the
[upstream GPG troubleshooting instructions](https://github.com/browserpass/browserpass-native#error-unable-to-fetch-and-parse-login-fields).
GPG needs a GUI pinentry such as `pinentry-mac`; configure its absolute path with
`pinentry-program` in `~/.gnupg/gpg-agent.conf`, then restart the agent with
`gpgconf --kill gpg-agent`. If GPG cannot be found, set its absolute path using
the extension's `gpgPath` option or `.browserpass.json` in the password store.

## Encrypted files

Files matching `*.secret` and `*.secret.*` are encrypted with
[git-crypt](https://github.com/AGWA/git-crypt) using a GPG key. They appear as
plaintext in the working tree but are stored encrypted in git.

On a new machine:

1. Import the GPG private key: `gpg --import <key-file>`
2. Install git-crypt: `brew install git-crypt`
3. Unlock the repo: `git-crypt unlock`

`bootstrap_macos.zsh` imports the keys supplied through `--key-dir`, marks the
imported *secret* keys ultimately trusted, and unlocks the repository before
installing the Brewfile packages. Ultimate ownertrust is applied to those keys
for subsequent GPG use; git-crypt decryption itself does not require it, so
public keys in the same directory are left untrusted.

Before installing packages or running tool setups, bootstrap also validates the
effective Git filters and secret-file attributes, checks for ciphertext left in
working files, and verifies decryption/re-encryption through Git. These checks run
on every invocation, even when the repository's local key already exists. Local
plaintext edits are allowed and are preserved by validation.

If a secret Zsh script produces a parse error on line 1, check whether its working
copy still contains git-crypt ciphertext. A key file alone does not establish that
the working tree is decrypted, and `git-crypt status -e` reports encryption in Git,
not whether applications can read the working files. Do not stage ciphertext from
an already-unlocked working tree: the clean filter would encrypt it again.

For a working file confirmed to be an exact copy of its encrypted index blob,
restore its decrypted contents with the configured Git filters:

```sh
git restore --worktree -- path/to/file.secret.zsh
```

Use only the verified paths: restore replaces working contents with the indexed
version. Repair missing or broken filter configuration before restoring files.

Greetings from the past

## for Raspberry Pi

- Install git `sudo apt install git -y`

- Clone this repository with
`git clone https://codeberg.org/pedrusck/.dotfiles.git`

- Run the initialization [script](./bootstrap_raspotify.bash) with `./bootstrap_raspotify.bash`.
