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

Brewfile failures do not immediately abort bootstrap. Homebrew reports failed
packages, and the closing summary prints a retry command. A later setup failure
can still stop the script before that summary.

Ultimate ownertrust is granted **only to imported keys that carry secret key
material**, including unchanged secret-key imports on reruns. Public-only imports
and unrelated keys retain their existing ownertrust.

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
Installing a tool with mise does not run its repository `setup.sh`; bootstrap
only runs scripts listed in the selected [profile](./profiles/development.sh).

### CLI tools with mise

[`mise/configuration.toml`](./mise/configuration.toml) defines CLI tools and language
runtimes. Tools are configured as `latest`; run `mise upgrade` to update installed
versions. Project configurations can override these version selections.

Bootstrap runs `mise/setup.sh`, which installs mise from `https://mise.run` at
`~/.local/bin/mise` if no executable exists there, links and trusts configuration,
and generates mise's Zsh completion. It does not install the configured tools or
update an existing mise executable. The Zsh configuration prefers this executable
over Homebrew's mise before activation in login and non-login interactive shells.

GNU Parallel, htop, QPDF, zsh-autosuggestions, and zsh-syntax-highlighting use
explicit `conda:` entries; PostgreSQL's `postgres` shorthand also selects
`conda:postgresql`. These use conda-forge packages without a separate Conda
installation. LuaJIT is also mise-managed. Browserpass, `mas`, and zsh-vi-mode
remain in the [Brewfile](./homebrew/Brewfile); bootstrap installs git-crypt through
Homebrew separately. Neither manifest explicitly installs SQLite or Make; the
setup relies on Apple's SQLite and developer-tools Make. Homebrew may install
overlapping dependencies, and command selection depends on `PATH`.

#### Install tools

Source builds require the Xcode Command Line Tools. SwiftPM packages also require
an existing compatible Swift toolchain; check it with `xcrun swift --version`.
Installing the `swiftly` or `xcodes` managers does not itself install a Swift
toolchain or Xcode.

OpenCode V2 uses `npm:@opencode/cli` through mise's `opencode` shorthand and
explicitly depends on mise-managed Node.js. This mapping requires mise 2026.10.9
or later. Check `"$HOME/.local/bin/mise" --version`; update an older standalone
installation with `"$HOME/.local/bin/mise" self-update` before proceeding.

After bootstrap, run from the repository root:

```sh
export PATH="$HOME/.local/bin:$PATH"
command mise --cd "$HOME" install
command mise --cd "$HOME" exec -- misecompsync --shell zsh
command mise --cd "$HOME" exec -- sh "$PWD/herdr/setup.sh"
exec zsh -l
```

These commands install missing tools, sync completions, and install Herdr's file
viewer plugin. `command mise` bypasses any existing shell function tied to an older
mise executable. `--cd "$HOME"` avoids the checkout's project context but still
reads any applicable home-directory configuration. See [Browserpass](#browserpass)
to register hosts after installing another supported browser.

#### Update tools

```sh
mise upgrade --global --no-prune
mise --cd "$HOME" exec -- misecompsync --shell zsh
exec zsh -l
```

`--global` targets globally configured tools; `--no-prune` keeps the tool versions
replaced by the upgrade. Mise maintains shims during its own installs and upgrades.

Update mise itself with `mise self-update`, then rerun `sh mise/setup.sh` from the
repository root to refresh its completion.

#### Shell completions

[`mise-completions-sync`](https://github.com/alltuner/mise-completions-sync) is
installed through mise as `misecompsync`. The global post-install hook runs
`misecompsync --shell zsh --new-only` when the command is available. The initial
full sync above also covers previously installed tools.

Zsh adds `${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions/zsh` to `fpath`
before `compinit`. Completion-sync writes its files after installations;
Zsh loads them through `fpath`. `MISE_COMPLETIONS_SYNC_HOME` overrides the base output
directory, and `MISE_COMPLETIONS_SYNC_ZSH_DIR` overrides the Zsh directory.
`mise/setup.sh` generates `_mise` there and links the
[custom registry](./mise/completions-registry.toml) under
`${XDG_DATA_HOME:-$HOME/.local/share}/mise-completions-sync/registry.toml`.
The registry adds Bottom, QPDF, and Skim (`sk`, the fuzzy finder, unrelated to the
Homebrew-installed Skim PDF application).
OpenCode's completion is supported by the sync tool's built-in registry.
PostgreSQL commands use Zsh's built-in `_postgresql` completion.

To refresh completions manually, including after changing registry entries:

```sh
mise --cd "$HOME" exec -- misecompsync --shell zsh
```

Use a full sync rather than `--new-only` for already-installed tools. If you run
`misecompsync clean`, rerun `sh mise/setup.sh` from the repository root afterward:
cleanup can remove `_mise` because standalone mise is not a mise-managed tool.

Open a new shell after syncing to register newly added completions. Completions
reflect the synchronized tool versions; switching project versions alone does
not trigger the post-install hook. Use `misecompsync --shell zsh --current` to
resync for the current project's selections. This overwrites shared completion
files; it does not create project-local completions.

#### Shell plugins

Zsh loads autosuggestions and syntax highlighting from installation prefixes
resolved in the home-directory context with `mise --cd "$HOME" where conda:<plugin>`.
These two plugins load exclusively from mise; zsh-vi-mode loads from Homebrew.
Syntax highlighting loads after autosuggestions. Zsh's built-in `_htop` provides
htop completion. GNU Parallel ships Bash completion, which is not loaded in Zsh.
Fzf's completion and keybindings are loaded separately with `fzf --zsh` during
shell initialization.

#### Migrate from Homebrew

To replace a Homebrew installation of mise, run from the repository root:

```sh
sh mise/setup.sh
"$HOME/.local/bin/mise" reshim
"$HOME/.local/bin/mise" doctor
"$HOME/.local/bin/mise" ls
exec zsh -l
```

Verify that `whence -p mise` prints `$HOME/.local/bin/mise` (with `$HOME` expanded)
and that managed tools work. Then run `brew uninstall mise` and check command
resolution and completion in another new interactive login shell. With the same
configuration and data paths, the standalone installation reuses installed tools.

Removal of redundant Homebrew copies is manual, after verifying their mise
replacements. Packages still declared in the Brewfile remain Homebrew-managed.

To replace Homebrew copies of the explicitly Conda-backed tools:

```sh
sh mise/setup.sh
mise --cd "$HOME" install conda:parallel conda:htop conda:qpdf \
  conda:zsh-autosuggestions conda:zsh-syntax-highlighting
mise --cd "$HOME" exec -- misecompsync --shell zsh
exec zsh -l
```

Check command resolution with `mise which <command>` and `type -a <command>`.
Verify QPDF completion, autosuggestions, highlighting, and vi-mode bindings.
Check each formula's installed dependents with
`brew uses --installed --recursive <formula>`, then remove the verified Homebrew
copies:

```sh
brew uninstall parallel htop qpdf \
  zsh-autosuggestions zsh-syntax-highlighting
```

Keep Homebrew's git-crypt: it has no mise configuration entry, and bootstrap
installs it before unlocking this repository.

Open another login shell and verify command resolution and plugin behavior again.
To roll back one of these tools, reinstall its Homebrew formula, restore its
Brewfile declaration, and remove its `conda:` declaration from the mise config.
For the shell plugins, also update `zsh/zshrc` to source the reinstalled Homebrew
plugin instead of resolving its mise prefix. Removing a mise configuration entry
alone does not change the plugin loader; it has no Homebrew fallback.

To install or update the Brewfile packages from the repository root:

```sh
brew bundle --file=homebrew/Brewfile
```

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

The Brewfile installs Helium, Brave, and LibreWolf. This script does not register
hosts for Brave or LibreWolf; configure those separately if needed. Firefox and
Floorp are supported when installed independently.

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
For graphical passphrase prompts, use a GUI pinentry such as the Brewfile's
`pinentry-mac`; set `pinentry-program` to its absolute path in
`~/.gnupg/gpg-agent.conf`, then restart the agent with
`gpgconf --kill gpg-agent`. If GPG cannot be found, set its absolute path using
the extension's `gpgPath` option or `.browserpass.json` in the password store.

## Encrypted files

Files matching `*.secret` and `*.secret.*` are encrypted with
[git-crypt](https://github.com/AGWA/git-crypt). A GPG private key unlocks the
repository's encryption key. After unlocking, files appear as plaintext in the
working tree but are stored encrypted in Git.

To unlock manually on a machine with Homebrew installed:

1. Install the decryption tools: `brew install gnupg git-crypt`
2. Import the GPG private key: `gpg --import <key-file>`
3. From the repository checkout, run `git-crypt unlock`.

`bootstrap_macos.zsh` imports the keys supplied through `--key-dir`, marks the
imported *secret* keys ultimately trusted, and unlocks the repository before
installing the Brewfile packages. Ultimate ownertrust is applied to those keys
for subsequent GPG use; git-crypt decryption itself does not require it.
Public-only imports retain their existing ownertrust.

After installing the decryption tools and before installing the Brewfile packages
or running tool setups, bootstrap validates the effective Git filters and
secret-file attributes, checks for ciphertext left in working files, and verifies
decryption/re-encryption through Git. These checks run
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
for its options. Install XZ first if unavailable (`brew install xz`); neither
package manifest declares it explicitly. The timezone defaults to the Mac's
detected timezone, falling back to UTC; override it with `--timezone`.
The script requires a card of at least 8 GB and asks for confirmation before
downloading and verifying the image. It does not compare the uncompressed image
size with the card's capacity. Wi-Fi credentials are not checked for control
characters, and quotes or backslashes may not survive configuration generation.

After flashing and booting the Pi, connect over SSH as the non-root user created
by the flash script. Download and run the bootstrap **on the Pi**:

```bash
curl -fsSL \
  https://codeberg.org/pedrusck/.dotfiles/raw/branch/main/bootstrap_raspotify.bash \
  -o bootstrap_raspotify.bash &&
  sudo bash bootstrap_raspotify.bash --name "Living Room"
```

Requires a Pi 4/5-family board, Raspberry Pi OS/Debian 13+, completed cloud-init,
internet access, passwordless sudo and a USB audio interface with exactly one
playback PCM. Set `USB_AUDIO_CARD_ID="CI1"` near the top of the downloaded script
to the card ID shown by `aplay -l`. The script verifies that this exact card is a
USB interface, probes direct 44.1 kHz stereo support, and chooses a supported
24-bit format, falling back to 16-bit. Playback uses 320 kbps.

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

Local syntax and static checks (no Pi or root privileges needed):

```bash
bash -n bootstrap_raspotify.bash
zsh -n bootstrap_raspotify_sd_card.zsh
shellcheck bootstrap_raspotify.bash
```

Install ShellCheck separately if needed (`brew install shellcheck`); neither
package manifest declares it. No automated regression tests are included in this
checkout. These checks do not verify flashing, generated configuration, or
hardware behavior.

Physical LED behavior still requires verification on a Pi 4 and Pi 5 after boot
and reboot: the activity and power LEDs should be off, with `none` selected in
`/sys/class/leds/*/trigger` and zero in `/sys/class/leds/*/brightness`. Firmware
startup and fault indications may still occur; `--keep-leds` skips the LED edits.
