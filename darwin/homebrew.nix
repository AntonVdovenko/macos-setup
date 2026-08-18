{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # MUST stay "none". "zap" would uninstall the ~25 apps in /Applications
      # that this repo does not declare (Office, Xcode, Adobe, Steam, VLC, ...).
      cleanup = "none";
    };

    taps = [
      "nikitabobko/tap"
    ];

    brews = [
      # macOS-specific cleanup utility, not packaged in nixpkgs.
      "mole"
    ];

    casks = [
      # Dev & windowing
      "ghostty"
      "visual-studio-code"
      "dbeaver-community"
      "orbstack"
      "nikitabobko/tap/aerospace"
      # Cask name is "hiddenbar", not "hidden-bar". Note this installs the
      # GitHub release; the source machine's copy came from the App Store.
      "hiddenbar"

      # Fonts
      "font-jetbrains-mono"
      "font-meslo-lg-nerd-font"

      # AI CLIs
      "codex"
      "claude-code"

      # AI desktop apps & comms
      "claude"
      "chatgpt"
      "slack"
      "telegram"
      "discord"
      "whatsapp"
    ];

    masApps = { };
  };
}
