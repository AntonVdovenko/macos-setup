{ host, ... }:
{
  imports = [
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs.hostPlatform = host.system;

  networking.hostName = host.hostname;
  networking.computerName = host.hostname;

  system.primaryUser = host.username;
  system.stateVersion = 6;

  users.users.${host.username}.home = "/Users/${host.username}";

  # Determinate Nix owns /etc/nix/nix.conf (the file is stamped "do not modify!
  # this file will be replaced!") and runs its own daemon, determinate-nixd.
  # nix-darwin must not manage Nix or the two fight over that file. This also
  # rules out nix.settings and nix.gc — Determinate handles garbage collection
  # itself, and nix-command/flakes are already enabled in its config.
  nix.enable = false;

  # Sudo via Touch ID. Approved addition, not present on the source machine.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Makes /etc/zshrc source the nix profile so nix-installed tools land on PATH.
  programs.zsh.enable = true;
}
