{ host, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./files.nix
    ./tmux-plugins.nix
  ];

  home.username = host.username;
  home.homeDirectory = host.homeDirectory;
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
