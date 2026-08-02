{ pkgs, ... }:
{
  # zsh-autosuggestions and zsh-syntax-highlighting are deliberately absent:
  # programs.zsh in shell.nix enables them and installs them itself.
  #
  # libpq is deliberately absent: postgresql_14 already provides pg_config and
  # the client libraries, and installing both collides in the profile.
  home.packages = with pkgs; [
    # Prompt & navigation
    oh-my-posh
    zoxide
    fzf

    # File & text tools
    bat
    eza
    fd
    ripgrep
    jq
    yazi
    tldr
    pandoc

    # System monitoring
    duf
    htop
    glances

    # Git & dev tooling
    gh
    lazygit
    lazydocker
    neovim
    tmux

    # Command runner for this repo's justfile
    just

    # Languages & runtimes
    go
    nodejs
    uv
    mise
    # staticcheck ships inside go-tools; there is no top-level `staticcheck`.
    go-tools

    # Cloud & data
    awscli2
    google-cloud-sdk
    minikube
    postgresql_14

    # Media
    ffmpeg

    # Alternative shell
    nushell
  ];
}
