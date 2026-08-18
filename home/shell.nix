{ host, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      # The source machine sets ZSH_THEME="" — oh-my-posh draws the prompt.
      theme = "";
    };

    shellAliases = {
      ll = "eza --long -a";
      route_reset = "sudo route delete default && sudo route add default 192.168.50.1";
    };

    initContent = ''
      # oh-my-posh — a different theme inside tmux, matching the source machine.
      if [ -n "$TMUX" ]; then
        eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/config-tmux.json)"
      else
        eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/config.json)"
      fi
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # programs.fzf is deliberately NOT enabled. fzf is installed on the source
  # machine but its zsh keybindings are never sourced, so enabling integration
  # would rebind Ctrl-R and change how the shell behaves.

  home.sessionPath = [
    # useUserPackages installs the Home Manager profile here. nix-darwin does
    # not add it automatically when Determinate Nix owns the daemon and
    # `nix.enable = false`.
    "/etc/profiles/per-user/${host.username}/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
