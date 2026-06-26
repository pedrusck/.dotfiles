# Dotfiles

To my future self,

## for macOS

In the machine to be set upped, first install command line tools with `xcode-select --install`.

Set the machine name in the settings and restart.
- in German go to Systemeinstellungen > Freigaben > Gerätename
- in English go to System Preferences > Sharing > Computer Name

Sign in App Store (to allow app installation with `mas` in Homebrew).

Clone this repository with
`git clone https://gitlab.com/pereBohigas/.dotfiles.git`

Import your GPG key and unlock encrypted files before running bootstrap:

```
gpg --import <your-private-key>
brew install git-crypt
git-crypt unlock
```

Run the initialization [script](./bootstrap.sh) with `./bootstrap.sh`.

And later on follow the steps in the [list](./macOS_setup_steps.md)

## Encrypted files

Files matching `*.secret` and `*.secret.*` are encrypted with [git-crypt](https://github.com/AGWA/git-crypt) using a GPG key. They appear as plaintext in the working tree but are stored encrypted in git.

On a new machine:
1. Import the GPG private key: `gpg --import <key-file>`
2. Install git-crypt: `brew install git-crypt`
3. Unlock the repo: `git-crypt unlock`

The bootstrap script will also attempt to unlock automatically after installing Homebrew packages.

Greetings from the past

## for Raspberry Pi

- Install git `sudo apt install git -y`

- Clone this repository with
`git clone https://gitlab.com/pereBohigas/.dotfiles.git`

- Run the initialization [script](./bootstrap_raspotify.sh) with `./bootstrap_raspotify.sh`.
