{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Anton";
        email = "vdovenkoantono@gmail.com";
      };
      core.autocrlf = "input";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # gitCredentialHelper is on by default and writes the credential.helper
  # entries for github.com and gist.github.com itself — setting them by hand in
  # settings above collides with it and fails to evaluate.
  #
  # It emits the same two-entry form the source machine has (an empty helper to
  # reset, then the gh helper), but pointing at the nix-store gh rather than the
  # hardcoded /Users/User/.local/bin/gh. That hardcoded path is one of the four
  # approved deviations.
  programs.gh.enable = true;
}
