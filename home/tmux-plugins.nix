{ pkgs, lib, ... }:
let
  src = { owner, repo, rev, hash }:
    pkgs.fetchFromGitHub { inherit owner repo rev hash; };

  # Revisions are the exact commits running on the source machine, so a new Mac
  # gets what this one has rather than whatever master happens to be that day.
  tpm = src {
    owner = "tmux-plugins";
    repo = "tpm";
    rev = "99469c4a9b1ccf77fade25842dc7bafbc8ce9946";
    hash = "sha256-hW8mfwB8F9ZkTQ72WQp/1fy8KL1IIYMZBtZYIwZdMQc=";
  };
  sensible = src {
    owner = "tmux-plugins";
    repo = "tmux-sensible";
    rev = "25cb91f42d020f675bb0a2ce3fbd3a5d96119efa";
    hash = "sha256-sw9g1Yzmv2fdZFLJSGhx1tatQ+TtjDYNZI5uny0+5Hg=";
  };
  resurrect = src {
    owner = "tmux-plugins";
    repo = "tmux-resurrect";
    rev = "cff343cf9e81983d3da0c8562b01616f12e8d548";
    hash = "sha256-FcSjYyWjXM1B+WmiK2bqUNJYtH7sJBUsY2IjSur5TjY=";
  };
  continuum = src {
    owner = "tmux-plugins";
    repo = "tmux-continuum";
    rev = "0698e8f4b17d6454c71bf5212895ec055c578da0";
    hash = "sha256-W71QyLwC/MXz3bcLR2aJeWcoXFI/A3itjpcWKAdVFJY=";
  };
  yank = src {
    owner = "tmux-plugins";
    repo = "tmux-yank";
    rev = "acfd36e4fcba99f8310a7dfb432111c242fe7392";
    hash = "sha256-/5HPaoOx2U2d8lZZJo5dKmemu6hKgHJYq23hxkddXpA=";
  };

  # Not TPM-managed on the source machine: tmux.conf loads it with a bare `run`
  # line and no `set -g @plugin`, so `prefix + I` would never install it and the
  # status bar would render raw #{E:@catppuccin_status_*} placeholders.
  catppuccin = src {
    owner = "catppuccin";
    repo = "tmux";
    rev = "8b0b9150f9d7dee2a4b70cdb50876ba7fd6d674a";
    hash = "sha256-godCgBMgqzim+W3O2sHcgw91h7sHsKHjd02BdLuazZ8=";
  };
in
{
  home.file = {
    ".tmux/plugins/tpm".source = tpm;
    ".tmux/plugins/tmux-sensible".source = sensible;
    ".tmux/plugins/tmux-resurrect".source = resurrect;
    ".tmux/plugins/tmux-continuum".source = continuum;
    ".tmux/plugins/tmux-yank".source = yank;
  };

  xdg.configFile."tmux/plugins/catppuccin".source = catppuccin;
}
