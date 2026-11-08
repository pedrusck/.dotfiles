#!/bin/sh

# Development profile — the tools configured by a bootstrap script

PROFILE_TOOLS="zsh git vim ssh starship browserpass neovim ghostty lazygit gitui tuicr amethyst herdr mise opencode pi_coding_agent"

# Optional mise migrations: enable the matching tool in mise/configuration.toml.
# These opt-ins run existing setup.sh scripts during bootstrap; they link config
# independently of installing binaries. From the repository root, the scripts
# can also be run manually after installation with /bin/sh <directory>/setup.sh.

# Link ~/.config/oh_my_posh/configuration.toml; select its prompt in zsh/zshrc.
# PROFILE_TOOLS="$PROFILE_TOOLS oh_my_posh"

# Link ~/.config/zellij/config.kdl and the custom default layout.
# PROFILE_TOOLS="$PROFILE_TOOLS zellij"

# Initialize local settings.json and link anthropic_key.sh under CLAUDE_CONFIG_DIR
# (default ~/.claude); also install the Claude integration when Herdr is available.
# PROFILE_TOOLS="$PROFILE_TOOLS claude_code"
