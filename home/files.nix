{ lib, ... }:
let
  dotfiles = ../dotfiles;
in
{
  home.file = {
    ".aerospace.toml".source = "${dotfiles}/aerospace/aerospace.toml";
    ".tmux.conf".source = "${dotfiles}/tmux/tmux.conf";
  };

  xdg.configFile = {
    "ghostty/config".source = "${dotfiles}/ghostty/config";

    # recursive = true symlinks each file individually. Without it the whole
    # directory becomes one store symlink and Ghostty cannot see into it.
    "ghostty/shaders" = {
      source = "${dotfiles}/ghostty/shaders";
      recursive = true;
    };

    "oh-my-posh/config.json".source = "${dotfiles}/oh-my-posh/config.json";
    "oh-my-posh/config-tmux.json".source = "${dotfiles}/oh-my-posh/config-tmux.json";

    # Global gitignore. Set here rather than via programs.git.ignores, which
    # writes this same path and would collide.
    "git/ignore".source = "${dotfiles}/git/ignore";
  };

  # VS Code settings are copied, not symlinked, so the settings UI can still
  # write to them. Copy only when absent — never overwrite live edits.
  # `just sync-vscode` is the path back into the repo.
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    vscodeUser="$HOME/Library/Application Support/Code/User"
    run mkdir -p "$vscodeUser"
    for f in settings.json keybindings.json; do
      if [ ! -e "$vscodeUser/$f" ]; then
        run install -m 644 "${dotfiles}/vscode/$f" "$vscodeUser/$f"
      fi
    done
  '';
}
