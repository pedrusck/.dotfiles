# Dotfiles

To my future self,

## for macOS

Do these three manual steps first:

1. **Install the Xcode command line tools** (provides `git` for cloning):

   ```
   xcode-select --install
   ```

2. **Sign in to the App Store** so Homebrew can install the `mas` apps in the Brewfile.

3. **Clone this repository and enter it:**

   ```
   git clone https://codeberg.org/petrusck/.dotfiles.git
   cd .dotfiles
   ```

Then insert the pendrive holding your GPG keys and run the initialization
[script](./bootstrap.zsh):

```
./bootstrap.zsh --key-dir /Volumes/<PENDRIVE>
```

`bootstrap.zsh` installs Homebrew and the Brewfile packages, imports the GPG
keypair from `--key-dir` and marks it ultimately trusted, unlocks the git-crypt
encrypted files, configures every tool in the `development` profile, and sets the
macOS keybindings that would otherwise collide with Amethyst/Neovim. The script
is idempotent, so it is safe to re-run.

When it finishes it prints the one remaining manual keybinding step
(Switch to Desktop 1–9 for Amethyst). Afterwards, follow the rest of the steps in
the [list](./macOS_setup_steps.md).

> The GPG import and `git-crypt unlock` are done automatically by `bootstrap.zsh`.
> To do them by hand instead:
>
> ```
> gpg --import <your-private-key>
> brew install git-crypt
> git-crypt unlock
> ```

## Encrypted files

Files matching `*.secret` and `*.secret.*` are encrypted with [git-crypt](https://github.com/AGWA/git-crypt) using a GPG key. They appear as plaintext in the working tree but are stored encrypted in git.

On a new machine:
1. Import the GPG private key: `gpg --import <key-file>`
2. Install git-crypt: `brew install git-crypt`
3. Unlock the repo: `git-crypt unlock`

`bootstrap.zsh` does this automatically when given `--key-dir`: it imports the keys, marks them trusted, and unlocks the repository before installing the Brewfile packages.

Greetings from the past

## for Raspberry Pi

- Install git `sudo apt install git -y`

- Clone this repository with
`git clone https://codeberg.org/petrusck/.dotfiles.git`

- Run the initialization [script](./bootstrap_raspotify.sh) with `./bootstrap_raspotify.sh`.
