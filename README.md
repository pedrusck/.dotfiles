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
source, and Switch to Desktop 1–9 for Amethyst). Install the mise tools as described
below, then follow the rest of the steps in the [list](./macOS_setup_steps.md).

### Running individual tool setups

Each `setup.sh` resolves repository files relative to its own location, so these
invocations are equivalent:

```sh
# From the repository root
sh neovim/setup.sh

# From the tool directory
cd neovim
sh setup.sh

# From any directory
sh /absolute/path/to/.dotfiles/neovim/setup.sh
```

Execute the scripts rather than sourcing them. The script's checkout determines
the source files; an externally supplied `DOTFILES_PATH` does not override it.

### CLI tools with mise

`mise/setup.sh` installs the standalone mise executable from `https://mise.run`
to `~/.local/bin/mise` when it is missing. Zsh prefers this directory over
Homebrew before activating mise, in both login and non-login interactive shells.
Setup uses the standalone executable explicitly to trust configuration and
generate mise's own Zsh completion.

[`mise/configuration.toml`](./mise/configuration.toml) manages CLI tools and language
runtimes. Sections are alphabetical; tools follow `latest` and have inline
descriptions.
GNU Parallel, git-crypt, htop, QPDF, zsh-autosuggestions, and
zsh-syntax-highlighting use mise's `conda:` backend with conda-forge packages.
mise manages their dependencies without a separate Conda installation.
PostgreSQL's `postgres` shorthand resolves to `conda:postgresql`.
OpenCode V2's `opencode` shorthand resolves to `npm:@opencode/cli` (requires mise
2026.10.9 or later), with an explicit dependency on mise-managed Node.js. npm runs
the package's postinstall script to select its native executable.
Browserpass, LuaJIT, and `mas` are also managed by Homebrew.
`sqlite3` and `make` use the macOS-provided versions. Homebrew may still install
SQLite as a dependency of other packages.

After bootstrap, install or update the CLI tools manually from this checkout:

```sh
sh mise/setup.sh
export PATH="$HOME/.local/bin:$PATH"
mise --cd "$HOME" install
mise --cd "$HOME" upgrade --global --no-prune
mise reshim
mise --cd "$HOME" exec -- misecompsync --shell zsh
sh browserpass/setup.sh
mise --cd "$HOME" exec -- sh "$PWD/herdr/setup.sh"
exec zsh -l
```

These commands link the configuration, install missing tools, upgrade to the
latest releases, sync completions, and configure Browserpass and Herdr.
The upgrade command retains previous mise versions.
Project-specific mise configurations still select their own tool versions.

Update mise itself with `mise self-update`; `mise upgrade` updates managed tools.
After updating mise, rerun `sh mise/setup.sh` to refresh its completion.

To finish migrating an existing Homebrew installation of mise, run:

```sh
sh mise/setup.sh
"$HOME/.local/bin/mise" reshim
"$HOME/.local/bin/mise" doctor
"$HOME/.local/bin/mise" ls
```

In a fresh login shell, verify that `command -v mise` resolves to
`~/.local/bin/mise` and that managed tools work. Then run `brew uninstall mise`
and check command resolution and completion in another fresh shell. The standalone
installation reuses the existing mise configuration and installed tools.

#### Shell completions

[`mise-completions-sync`](https://github.com/alltuner/mise-completions-sync) is
installed through mise as `misecompsync`. The global post-install hook runs
`misecompsync --shell zsh --new-only` when the command is available. The initial
full sync above also covers previously installed tools.

Zsh adds `${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions/zsh` to `fpath`
before `compinit`; completions are generated after installations rather than
during shell startup. `MISE_COMPLETIONS_SYNC_HOME` overrides the base output
directory, and `MISE_COMPLETIONS_SYNC_ZSH_DIR` overrides the Zsh directory.
`mise/setup.sh` generates `_mise` in that completion directory and links the custom
registry in `mise/completions-registry.toml`, which adds Bottom's bundled completion,
QPDF's `qpdf --completion-zsh` generator, and Skim's `sk --shell zsh` generator,
under `${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions-sync/registry.toml`.
OpenCode's completion is supported by the sync tool's built-in registry.
PostgreSQL commands use Zsh's built-in `_postgresql` completion.

To refresh completions manually or remove entries for uninstalled tools:

```sh
misecompsync --shell zsh
misecompsync clean
```

After adding or changing registry entries for already-installed tools, run a full
sync with `mise --cd "$HOME" exec -- misecompsync --shell zsh` rather than
`--new-only`. The generated files include `_btm`, `_qpdf`, and `_sk`.

Open a new shell after syncing to register newly added completions. Completions
reflect the synchronized tool versions; switching project versions alone does
not trigger the post-install hook. Use `misecompsync --shell zsh --current` to
resync for the current project's selections. The former
`${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions` directory is no longer loaded.

Source builds need the Xcode Command Line Tools, and SwiftPM executables need a
compatible selected Swift toolchain (`xcrun --find swift`). The published
`defaultbrowser` executable requires Rosetta on Apple
Silicon; install Rosetta before using that tool.

Zsh loads autosuggestions and syntax highlighting from the global mise
installation prefixes, resolved with `mise --cd "$HOME" where conda:<plugin>`.
These two plugins load exclusively from mise; zsh-vi-mode loads from Homebrew.
Syntax highlighting loads after autosuggestions. Zsh's built-in `_htop` provides
htop completion. GNU Parallel ships Bash completion, which is not loaded in Zsh.

Removal of redundant Homebrew copies is manual, after verifying their mise
replacements. GUI applications, zsh-vi-mode, native libraries, and the remaining
utilities continue to use Homebrew.

To migrate the six Conda-backed tools on an existing machine:

```sh
sh mise/setup.sh
mise --cd "$HOME" install conda:parallel conda:git-crypt conda:htop conda:qpdf \
  conda:zsh-autosuggestions conda:zsh-syntax-highlighting
mise reshim
mise --cd "$HOME" exec -- misecompsync --shell zsh
exec zsh -l
```

Verify command ownership, QPDF completion, autosuggestions, highlighting, and
vi-mode bindings in the new shell. Check each formula's installed dependents
with `brew uses --installed --recursive <formula>`, then remove the verified
Homebrew copies:

```sh
brew uninstall parallel git-crypt htop qpdf \
  zsh-autosuggestions zsh-syntax-highlighting
```

Open another login shell and verify command ownership and plugin behavior again.
To roll back one of these tools, reinstall its Homebrew formula, restore its
Brewfile declaration, and remove its `conda:` declaration from the mise config.
For the shell plugins, also update `zsh/zshrc` to source the reinstalled Homebrew
plugin instead of resolving its mise prefix. Removing a mise configuration entry
alone does not change the plugin loader; it has no Homebrew fallback.

For subsequent Homebrew installs, including the Homebrew-managed `mas` CLI:

```sh
brew bundle --file=homebrew/Brewfile
```

The bootstrap script runs Homebrew before the mise setup step.
Project-specific mise selections retain priority. `mise/setup.sh` installs mise
if needed, links and trusts configuration, and generates its completion; managed
tool installation and upgrades use mise's own commands.

Check command ownership with `mise which <command>` and `type -a <command>` in a
new login shell. For rollback, reinstall the affected Homebrew formula before
removing its mise entry and rerun the affected setup script. Browserpass can be
repaired by reinstalling its Homebrew formula and rerunning `browserpass/setup.sh`.

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
Homebrew's stable Browserpass prefix (`/opt/homebrew/opt/browserpass`). Homebrew
supplies the manifests and native executable; package upgrades refresh their
paths without a custom launcher or repository-owned JSON templates.

Firefox and Floorp share one registration. Helium searches its own
`net.imput.helium/NativeMessagingHosts/` directory first. A registration there
is accepted if it resolves to the same Homebrew manifest; otherwise setup asks
you to move it aside. Setup skips when no
supported browser, Homebrew, or Homebrew-installed Browserpass is available.
Existing regular files, directories, and symlinks to directories at browser
registration destinations are preserved and reported as conflicts.

Install the Browserpass extension in each browser profile you use:

- [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/browserpass-ce/)
  for Floorp and Firefox.
- [Chrome Web Store](https://chromewebstore.google.com/detail/browserpass/naepdomgkenhinolocfifgehidddafch)
  for Helium.

To install Browserpass manually:

```sh
brew install amar1729/formulae/browserpass
sh browserpass/setup.sh
```

To repair a missing native executable or packaged manifest:

```sh
brew reinstall amar1729/formulae/browserpass
sh browserpass/setup.sh
```

Setup reports missing or invalid packaged manifests rather than creating broken
registrations. It can be run again after installing another supported browser.

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

Prepare the SD card on macOS with `bootstrap_raspotify_sd_card.zsh`; use `--help`
for its options. The timezone is always detected from the Mac's system
configuration, falling back to UTC if detection fails. The script checks the
verified image's uncompressed size against the card's actual capacity before
asking for confirmation. SSIDs and passwords support printable Unicode, quotes,
and backslashes; embedded control characters are rejected.

After flashing and booting the Pi, connect over SSH as the non-root user created
by the flash script. Download and run the bootstrap **on the Pi**:

```bash
curl -fsSL \
  https://codeberg.org/pedrusck/.dotfiles/raw/branch/main/bootstrap_raspotify.bash \
  -o bootstrap_raspotify.bash &&
  sudo bash bootstrap_raspotify.bash --name "Living Room"
```

Requires a Pi 4/5-family board, Raspberry Pi OS/Debian 13+, completed cloud-init,
internet access, passwordless sudo and a single connected USB audio interface.
Set `USB_AUDIO_CARD_ID="CI1"` near the top of the downloaded script to the card ID
shown by `aplay -l`. The script verifies that this exact card is a USB interface,
probes direct 44.1 kHz stereo support and
chooses a supported 24-bit format, falling back to 16-bit. Playback always uses
the maximum bitrate of 320 kbps.

Set `ZEROCONF_PORT=24879` near the top of the script to choose the discovery TCP
port (1025-65535). Raspotify and the firewall both use this value.

Set `WAIT_TIMEOUT=600` there to configure how long to wait for cloud-init,
package-manager locks and Raspotify readiness after reboot (1-3600 seconds).
This does not limit the total installation or upgrade duration.

Inspect first with `sudo bash bootstrap_raspotify.bash --dry-run`; list options
with `bash bootstrap_raspotify.bash --help`. Piped execution is also supported
with `curl -fsSL URL | sudo -n bash -s -- [options]`, but downloading successfully
before execution is preferred. Do not invoke it from cloud-init.

Provisioning runs in a transient systemd service and continues if SSH disconnects.
When SSH/firewall settings change, reconnect using a **new SSH transport**:

```bash
ssh -o ControlMaster=no -o ControlPath=none pi@raspotify.local
sudo /run/pi-setup-access/confirm
```

Use your configured username and hostname. Run the confirmation command only
when the bootstrap requests it, within ten minutes; otherwise the previous SSH
and firewall settings are restored. An existing firewall manager or unrelated
nftables rules require `--no-firewall` or manual consolidation first.

The script upgrades packages by default, retains credentials, disables the audio
cache, uses RAM for temporary audio buffering, and schedules automatic OS updates
at 04:00/04:30 in the Pi's timezone. These include Debian security updates and the
Raspberry Pi/Raspbian main archives, which have no separate security-only channel.
Every provisioning run also executes `apt-get -y autoremove` without a simulation.
EEPROM updates require `--update-eeprom`. The hardware watchdog is opt-in.
`--no-*` options skip management rather than undo prior runs.

Reboots are reported unless `--reboot` is supplied. A one-shot verification service
checks the next boot when a reboot is required. After reconnecting, inspect:

```bash
sudo cat /var/lib/pi-setup/last-run
sudo tail -n 100 /var/log/pi-setup.log
```

Changed files are backed up under `/var/backups/pi-setup/`. Retained bootstrap logs
are capped at run boundaries; the system journal is volatile by default. Finish
with a Spotify Premium playback session to verify audible output and stability.

Local regression checks (no Pi or root privileges needed):

```bash
bash -n bootstrap_raspotify.bash
shellcheck bootstrap_raspotify.bash
python3 -m unittest discover -s tests -p 'test_bootstrap_raspotify.py'
```

SD-card script checks require Zsh, XZ, and the test-only YAML parser:

```sh
python3 -m venv .venv-raspotify-tests
.venv-raspotify-tests/bin/python -m pip install -r tests/requirements.txt
zsh -n bootstrap_raspotify_sd_card.zsh
.venv-raspotify-tests/bin/python -m unittest discover -s tests -p 'test_bootstrap_raspotify_sd_card.py'
```

These checks use temporary files and mock disk, network, and privilege operations.
Physical LED behavior still requires verification on a Pi 4 and Pi 5 after boot
and reboot: the activity and power LEDs should be off, with `none` selected in
`/sys/class/leds/*/trigger` and zero in `/sys/class/leds/*/brightness`. Firmware
startup and fault indications may still occur; `--keep-leds` skips the LED edits.
