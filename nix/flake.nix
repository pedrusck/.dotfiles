{
  description = "macOS system flake — full CLI toolchain alternative to Homebrew";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {

      # All CLI tools — organized to mirror the Homebrew Brewfile categories.
      # GUI apps (casks) and Mac App Store apps remain Homebrew-only.
      environment.systemPackages = with pkgs; [

        # Version managers
        mise
        nvm
        pyenv
        rbenv

        # Shell plugins
        parallel
        starship
        zoxide
        zsh-autosuggestions
        zsh-syntax-highlighting
        zsh-vi-mode

        # Compilers & language tools
        ghcup
        pkl

        # Command runners
        just
        gnumake
        mask

        # Editors
        neovim

        # Version control
        git
        delta           # Homebrew: git-delta
        git-crypt
        git-lfs
        gitleaks
        gitui
        hub
        lazygit
        serie

        # File / memory management
        duf
        du-dust         # Homebrew: dust
        kondo
        superfile
        tree
        yazi

        # Process / system monitor
        bottom
        htop
        hyperfine

        # Networking
        atac
        curlie
        drill
        hurl
        inetutils       # Homebrew: telnet
        xh

        # Image manipulation (CLI)
        imagemagick
        viu

        # PDF
        ghostscript

        # Writing / typesetting
        presenterm
        typst

        # Keyboard tools
        gtypist         # Homebrew: gnu-typist
        toipe

        # User manual
        cheat
        tldr

        # File inspection
        bat
        eza
        fx
        glow
        jq
        jql
        qpdf
        hexyl
        tabiew
        tesseract
        tokei
        xq
        yq

        # File and content search
        fd
        fzf
        ripgrep
        ripgrep-all
        sd
        skim            # Homebrew: sk
        television

        # Terminal tools
        cmatrix
        herdr           # nixpkgs version may trail the Homebrew release

        # Password management
        pass

        # Database
        postgresql_17   # Homebrew: postgresql@17
        rainfrog

        # Music (CLI)
        ncspot

        # Video (CLI)
        ffmpeg

        # AI coding
        opencode

        # iOS / Swift development (CLI-compatible subset)
        dependency-check
        lizard          # Homebrew: lizard-analyzer
      ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Required since nix-darwin Jan 2025
      system.primaryUser = "petrusck";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild switch --flake .#macbook
    darwinConfigurations."macbook" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."macbook".pkgs;
  };
}
