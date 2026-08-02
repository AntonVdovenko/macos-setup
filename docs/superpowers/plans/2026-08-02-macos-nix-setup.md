# macOS Nix Setup Repo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a git repo that reconstructs this Mac's working environment on a new machine with one `darwin-rebuild switch`.

**Architecture:** A single flake exposes `darwinConfigurations.VdovenkoAnton`. nix-darwin owns root-level concerns (macOS defaults, Homebrew casks, Touch ID), home-manager runs as a nix-darwin module and owns user-level config, and hand-tuned configs live as verbatim files under `dotfiles/` that home-manager symlinks into place. Per-machine values live in one file under `hosts/`.

**Tech Stack:** Nix (flakes), nix-darwin, home-manager, Homebrew (casks only), `just` as the command runner, bash for the doctor/sync scripts.

## Global Constraints

- Source spec: `docs/superpowers/specs/2026-08-02-macos-nix-setup-design.md`. Where this plan and the spec disagree, the spec wins — raise the conflict rather than silently diverging.
- Host: `VdovenkoAnton`, user `User`, home `/Users/User`, platform `aarch64-darwin`, macOS 26.5.2.
- `homebrew.onActivation.cleanup` MUST be `"none"`. `"zap"` would uninstall the ~25 undeclared apps in `/Applications`. This is the single most destructive mistake available in this repo.
- No secrets in the repo, ever. No SSH keys, no tokens, no credential files. The repo must stay safe to publish.
- `dotfiles/` content is byte-identical to the source machine. Do not reformat, re-indent, or "improve" those files.
- Only four deviations from the source machine are permitted, all listed in the spec: gcloud from nixpkgs instead of `~/Downloads`, no Framework Python alias, no `~/.local/bin` hand-installs, and removal of the inert p10k/starship configs.
- Two corrections to the spec's package list, both made deliberately during planning: `libpq` is dropped because `postgresql_14` already provides `pg_config` and the client libraries and installing both collides in the profile; `mole` is added to `homebrew.brews` because it is installed on the source machine, is macOS-specific, and is not in nixpkgs — the spec's list omitted it.
- **The user has instructed that this work must not change or delete anything on their Mac (stated 2026-08-02).** Task 13 is therefore CANCELLED, not merely gated. Do not run `darwin-rebuild switch`. Do not modify, move or delete any file under `$HOME` outside this repo. Do not install or uninstall Homebrew packages.
- Every verification uses `nix build` / `nix eval`, which only write to `/nix/store` and leave the running system's configuration untouched. Build outputs go to the session scratchpad, never into `$HOME` or the repo.
- Commit after every task.

## File Structure

| Path | Responsibility |
| --- | --- |
| `flake.nix` | Inputs, and the single `darwinConfigurations` entry |
| `hosts/vdovenko-mbp.nix` | Per-machine literals: hostname, username, system |
| `darwin/default.nix` | Root-level: nix settings, stateVersion, Touch ID, primaryUser |
| `darwin/homebrew.nix` | Taps, casks, brews |
| `darwin/defaults.nix` | macOS system defaults |
| `home/default.nix` | home-manager entry point, imports the rest |
| `home/packages.nix` | CLI packages from nixpkgs |
| `home/shell.nix` | zsh, oh-my-zsh, prompt, aliases, PATH |
| `home/git.nix` | git and gh config |
| `home/files.nix` | dotfile symlinks + VS Code mutable copy |
| `home/tmux-plugins.nix` | Six pinned tmux plugin fetches |
| `dotfiles/**` | Verbatim configs |
| `justfile` | `switch`, `build`, `update`, `doctor`, `sync-vscode` |
| `scripts/doctor.sh` | Post-activation drift checks |
| `scripts/sync-vscode.sh` | Copy live VS Code settings back into the repo |
| `README.md` | What this is, how to use it |
| `MANUAL.md` | Post-install checklist for everything Nix cannot do |

---

### Task 1: Repo scaffolding and Nix installation

**Files:**
- Create: `.gitignore`
- Create: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: a working `nix` binary with flakes enabled; every later task's verification depends on it.

- [ ] **Step 1: Write `.gitignore`**

```gitignore
result
result-*
.DS_Store
.direnv/
```

- [ ] **Step 2: Write a README stub**

```markdown
# macOS setup

Declarative macOS configuration: nix-darwin + home-manager + Homebrew casks.

Rebuilt in full by `just switch`. See `MANUAL.md` for the steps Nix cannot do.
```

- [ ] **Step 3: Confirm with the user, then install Nix**

This creates a `/nix` volume, a daemon, and build users. **Ask the user before running it.** If they decline, stop — Tasks 3 onward cannot be verified without it.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

**This installs Determinate Nix regardless of flags.** Verified on 2026-08-02: `--determinate=false` is a parse error (the flag takes no value), and omitting the flag entirely still produced `Determinate Nix 3.21.9`. The installer no longer ships upstream Nix. The consequence is that `darwin/default.nix` must set `nix.enable = false` — see Task 3.

- [ ] **Step 4: Verify Nix works in a fresh shell**

Run: `zsh -lc 'nix --version && nix flake --help >/dev/null && echo FLAKES_OK'`
Expected: a version line followed by `FLAKES_OK`. If `nix: command not found`, the shell has not picked up `/etc/zshrc`'s daemon hook — prefix commands with `PATH="/nix/var/nix/profiles/default/bin:$PATH"` or open a new terminal.

- [ ] **Step 5: Commit**

```bash
git add .gitignore README.md
git commit -m "Add repo scaffolding"
```

---

### Task 2: Capture dotfiles verbatim

**Files:**
- Create: `dotfiles/ghostty/config`, `dotfiles/ghostty/shaders/**`
- Create: `dotfiles/aerospace/aerospace.toml`
- Create: `dotfiles/tmux/tmux.conf`
- Create: `dotfiles/oh-my-posh/config.json`, `dotfiles/oh-my-posh/config-tmux.json`
- Create: `dotfiles/git/ignore`
- Create: `dotfiles/vscode/settings.json`, `dotfiles/vscode/keybindings.json`, `dotfiles/vscode/extensions.txt`

**Interfaces:**
- Consumes: nothing.
- Produces: the `dotfiles/` tree consumed by `home/files.nix` (Task 8) and `scripts/doctor.sh` (Task 10).

- [ ] **Step 1: Copy every config across**

```bash
mkdir -p dotfiles/{ghostty,aerospace,tmux,oh-my-posh,git,vscode}
cp ~/.config/ghostty/config          dotfiles/ghostty/config
cp -R ~/.config/ghostty/shaders      dotfiles/ghostty/shaders
cp ~/.aerospace.toml                 dotfiles/aerospace/aerospace.toml
cp ~/.tmux.conf                      dotfiles/tmux/tmux.conf
cp ~/.config/oh-my-posh/config.json  dotfiles/oh-my-posh/config.json
cp ~/.config/oh-my-posh/config-tmux.json dotfiles/oh-my-posh/config-tmux.json
cp ~/.config/git/ignore              dotfiles/git/ignore
cp "$HOME/Library/Application Support/Code/User/settings.json"    dotfiles/vscode/settings.json
cp "$HOME/Library/Application Support/Code/User/keybindings.json" dotfiles/vscode/keybindings.json
code --list-extensions > dotfiles/vscode/extensions.txt
find dotfiles -name '.DS_Store' -delete
```

- [ ] **Step 2: Verify the copies are byte-identical**

```bash
diff  ~/.config/ghostty/config dotfiles/ghostty/config           && echo "ghostty OK"
diff -r ~/.config/ghostty/shaders dotfiles/ghostty/shaders       && echo "shaders OK"
diff  ~/.aerospace.toml dotfiles/aerospace/aerospace.toml        && echo "aerospace OK"
diff  ~/.tmux.conf dotfiles/tmux/tmux.conf                       && echo "tmux OK"
diff  ~/.config/oh-my-posh/config.json dotfiles/oh-my-posh/config.json && echo "omp OK"
diff  ~/.config/oh-my-posh/config-tmux.json dotfiles/oh-my-posh/config-tmux.json && echo "omp-tmux OK"
```

Expected: six `OK` lines and no diff output.

- [ ] **Step 3: Verify the extension list is complete**

Run: `wc -l < dotfiles/vscode/extensions.txt`
Expected: `31`. If it differs, VS Code has changed since the survey — record the actual number and carry on; the list is a snapshot, not a fixed constant.

- [ ] **Step 4: Confirm no secrets were captured**

```bash
grep -rIlE '(BEGIN .*PRIVATE KEY|gho_|ghp_|aws_secret|password)' dotfiles/ || echo "NO SECRETS FOUND"
```
Expected: `NO SECRETS FOUND`. If anything matches, stop and report before committing.

- [ ] **Step 5: Commit**

```bash
git add dotfiles
git commit -m "Capture dotfiles verbatim from VdovenkoAnton"
```

---

### Task 3: A flake that evaluates

**Files:**
- Create: `flake.nix`
- Create: `hosts/vdovenko-mbp.nix`
- Create: `darwin/default.nix`

**Interfaces:**
- Consumes: nothing.
- Produces: `darwinConfigurations.VdovenkoAnton`. `darwin/default.nix` imports `./homebrew.nix` and `./defaults.nix`, which Tasks 4 and 5 create — so this task's build is expected to fail until those files exist. Create them as empty stubs here (`{ }: { }`) and fill them in later.

- [ ] **Step 1: Write `hosts/vdovenko-mbp.nix`**

```nix
# Per-machine literals. A second Mac gets its own file here plus one line in flake.nix.
{
  hostname = "VdovenkoAnton";
  username = "User";
  system = "aarch64-darwin";
}
```

- [ ] **Step 2: Write `flake.nix`**

```nix
{
  description = "Anton's macOS configuration — nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nix-darwin, home-manager }:
    let
      host = import ./hosts/vdovenko-mbp.nix;
    in
    {
      darwinConfigurations.${host.hostname} = nix-darwin.lib.darwinSystem {
        inherit (host) system;
        specialArgs = { inherit inputs host; };
        modules = [
          ./darwin
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit inputs host; };
              users.${host.username} = import ./home;
            };
          }
        ];
      };
    };
}
```

`backupFileExtension` matters: on first activation home-manager refuses to overwrite an existing `~/.zshrc` unless it can move it aside.

- [ ] **Step 3: Write `darwin/default.nix`**

```nix
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

  # Determinate Nix owns /etc/nix/nix.conf and runs its own daemon
  # (determinate-nixd), so nix-darwin must not manage Nix. This also rules out
  # nix.settings and nix.gc — Determinate handles GC, and nix-command/flakes are
  # already enabled in its config.
  nix.enable = false;

  # Sudo via Touch ID. Approved addition, not present on the source machine.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Makes /etc/zshrc source the nix profile so nix-installed tools are on PATH.
  programs.zsh.enable = true;
}
```

- [ ] **Step 4: Create empty stubs so the imports resolve**

```bash
mkdir -p darwin home
printf '{ ... }:\n{\n}\n' > darwin/homebrew.nix
printf '{ ... }:\n{\n}\n' > darwin/defaults.nix
printf '{ host, ... }:\n{\n  home.username = host.username;\n  home.homeDirectory = "/Users/${host.username}";\n  home.stateVersion = "25.05";\n  programs.home-manager.enable = true;\n}\n' > home/default.nix
```

- [ ] **Step 5: Verify the flake evaluates**

Run: `nix flake check 2>&1 | tail -20`
Expected: no `error:` lines. First run downloads nixpkgs and takes several minutes.

- [ ] **Step 6: Verify the system builds**

Run: `nix build .#darwinConfigurations.VdovenkoAnton.system --no-link 2>&1 | tail -20`
Expected: exits 0, no `error:`. This is a build only — nothing is applied to the running system.

- [ ] **Step 7: Commit**

```bash
git add flake.nix flake.lock hosts darwin home
git commit -m "Add evaluating flake with nix-darwin and home-manager wiring"
```

---

### Task 4: Homebrew casks

**Files:**
- Modify: `darwin/homebrew.nix` (replace the stub)

**Interfaces:**
- Consumes: nothing.
- Produces: `config.homebrew.brewfile`, read by `scripts/doctor.sh` in Task 10.

- [ ] **Step 1: Write the failing check**

Run: `nix eval --raw .#darwinConfigurations.VdovenkoAnton.config.homebrew.brewfile | xargs cat | grep -c '^cask'`
Expected: `0` — the stub declares nothing. This is the baseline the next step must move.

- [ ] **Step 2: Write `darwin/homebrew.nix`**

```nix
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
      "rectangle"
      "hidden-bar"

      # Fonts
      "font-jetbrains-mono"
      "font-meslo-lg-nerd-font"

      # AI & comms
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
```

- [ ] **Step 3: Verify all 15 casks and the tap made it into the Brewfile**

```bash
BREWFILE=$(nix eval --raw .#darwinConfigurations.VdovenkoAnton.config.homebrew.brewfile)
cat "$BREWFILE"
echo "--- cask count ---"
grep -c '^cask' "$BREWFILE"
```
Expected: `15`, and the listing contains `tap "nikitabobko/tap"` and `brew "mole"`.

- [ ] **Step 4: Verify cleanup is not destructive**

Run: `nix eval .#darwinConfigurations.VdovenkoAnton.config.homebrew.onActivation.cleanup`
Expected: `"none"`. Any other value is a stop-the-line defect.

- [ ] **Step 5: Verify every cask name actually exists upstream**

```bash
for c in ghostty visual-studio-code dbeaver-community orbstack rectangle hidden-bar \
         font-jetbrains-mono font-meslo-lg-nerd-font claude chatgpt slack telegram discord whatsapp; do
  brew info --cask "$c" >/dev/null 2>&1 && echo "ok   $c" || echo "MISSING $c"
done
brew info --cask nikitabobko/tap/aerospace >/dev/null 2>&1 && echo "ok   aerospace" || echo "MISSING aerospace"
```
Expected: all `ok`. A `MISSING` line means the cask was renamed — find the current name with `brew search`, fix the list, and note the change in the commit message. Do not leave a broken name in.

- [ ] **Step 6: Commit**

```bash
git add darwin/homebrew.nix
git commit -m "Declare Homebrew taps, casks and brews"
```

---

### Task 5: macOS system defaults

**Files:**
- Modify: `darwin/defaults.nix` (replace the stub)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write `darwin/defaults.nix`**

Only settings the source machine actually has, plus nothing else — adding unset defaults would change how the machine feels.

```nix
{ ... }:
{
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 64;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
    };
  };
}
```

- [ ] **Step 2: Verify each default evaluates to the source machine's value**

```bash
nix eval .#darwinConfigurations.VdovenkoAnton.config.system.defaults.dock.autohide
nix eval .#darwinConfigurations.VdovenkoAnton.config.system.defaults.dock.tilesize
nix eval .#darwinConfigurations.VdovenkoAnton.config.system.defaults.NSGlobalDomain.AppleInterfaceStyle
```
Expected: `true`, `64`, `"Dark"` — matching `defaults read com.apple.dock autohide` (1), `tilesize` (64) and `AppleInterfaceStyle` (Dark) on this machine.

- [ ] **Step 3: Commit**

```bash
git add darwin/defaults.nix
git commit -m "Declare macOS dock and appearance defaults"
```

---

### Task 6: CLI packages

**Files:**
- Create: `home/packages.nix`
- Modify: `home/default.nix` (add the import)

**Interfaces:**
- Consumes: nothing.
- Produces: `home.packages`. Task 10's doctor script checks a subset of these resolve on PATH.

- [ ] **Step 1: Write `home/packages.nix`**

`zsh-autosuggestions` and `zsh-syntax-highlighting` are deliberately absent — Task 7 enables them through `programs.zsh`, which installs them itself. `libpq` is absent because `postgresql_14` already provides `pg_config` and the client libraries, and installing both collides in the profile.

```nix
{ pkgs, ... }:
{
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
    staticcheck

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
```

- [ ] **Step 2: Add the import to `home/default.nix`**

```nix
{ host, ... }:
{
  imports = [
    ./packages.nix
  ];

  home.username = host.username;
  home.homeDirectory = "/Users/${host.username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 3: Verify every attribute name resolves**

```bash
for p in oh-my-posh zoxide fzf bat eza fd ripgrep jq yazi tldr pandoc duf htop \
         glances gh lazygit lazydocker neovim tmux just go nodejs uv mise staticcheck \
         awscli2 google-cloud-sdk minikube postgresql_14 ffmpeg nushell; do
  nix eval --raw "nixpkgs#$p.name" >/dev/null 2>&1 && echo "ok   $p" || echo "MISSING $p"
done
```
Expected: all `ok`. A `MISSING` line means the attribute was renamed — find it with `nix search nixpkgs <name>`, fix `packages.nix`, and note the rename in the commit message.

- [ ] **Step 4: Build the home generation**

```bash
nix build .#darwinConfigurations.VdovenkoAnton.config.home-manager.users.User.home.activationPackage -o /tmp/hm
ls /tmp/hm/home-path/bin | head -40
```
Expected: the build succeeds and `home-path/bin` lists `bat`, `eza`, `rg`, `gh`, `nvim`, `gcloud` and the rest.

- [ ] **Step 5: Verify the gcloud deviation actually took**

Run: `ls -l /tmp/hm/home-path/bin/gcloud`
Expected: exists and resolves into `/nix/store`. This is the fix for the `~/Downloads/google-cloud-sdk` path — if `gcloud` is missing here, the deviation has not been implemented.

- [ ] **Step 6: Commit**

```bash
git add home/packages.nix home/default.nix
git commit -m "Declare CLI packages from nixpkgs"
```

---

### Task 7: zsh and git configuration

**Files:**
- Create: `home/shell.nix`
- Create: `home/git.nix`
- Modify: `home/default.nix` (add both imports)

**Interfaces:**
- Consumes: `home.packages` from Task 6 (`oh-my-posh` must be installed for the prompt init to resolve).
- Produces: a generated `~/.zshrc`. Task 8's dotfile symlinks must not collide with it.

- [ ] **Step 1: Write `home/shell.nix`**

`programs.fzf` is deliberately NOT enabled: the source machine has fzf installed but never sources its zsh keybindings, so enabling integration would rebind Ctrl-R and change how the shell feels.

```nix
{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
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

  home.sessionPath = [
    "$HOME/go/bin"
  ];
}
```

If `nix flake check` rejects `initContent` with "unknown option", this home-manager predates the rename — use `initExtra` with the same string instead.

- [ ] **Step 2: Write `home/git.nix`**

```nix
{ ... }:
{
  programs.git = {
    enable = true;
    userName = "Anton";
    userEmail = "vdovenkoantono@gmail.com";

    extraConfig = {
      core.autocrlf = "input";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      credential."https://github.com".helper = "!gh auth git-credential";
      credential."https://gist.github.com".helper = "!gh auth git-credential";
    };
  };

  programs.gh.enable = true;
}
```

The credential helper is `!gh auth git-credential`, not the source machine's absolute `/Users/User/.local/bin/gh` — that hardcoded path is one of the four approved deviations.

- [ ] **Step 3: Add both imports to `home/default.nix`**

```nix
{ host, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
  ];

  home.username = host.username;
  home.homeDirectory = "/Users/${host.username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 4: Build and inspect the generated `.zshrc`**

```bash
nix build .#darwinConfigurations.VdovenkoAnton.config.home-manager.users.User.home.activationPackage -o /tmp/hm
cat /tmp/hm/home-files/.zshrc
```

- [ ] **Step 5: Assert the generated `.zshrc` is correct**

```bash
Z=/tmp/hm/home-files/.zshrc
grep -q 'config-tmux.json'          "$Z" && echo "ok   tmux prompt variant"
grep -q "alias -- ll='eza --long -a'" "$Z" && echo "ok   ll alias"   # note: home-manager emits `alias -- name=value`
grep -q 'zoxide init zsh'           "$Z" && echo "ok   zoxide"
grep -q 'oh-my-zsh.sh'              "$Z" && echo "ok   oh-my-zsh"
grep -q 'Downloads/google-cloud-sdk' "$Z" && echo "FAIL Downloads gcloud leaked" || echo "ok   no Downloads gcloud"
grep -q 'Framework/Versions/3.12'    "$Z" && echo "FAIL python alias leaked"     || echo "ok   no python alias"
grep -q 'p10k'                       "$Z" && echo "FAIL p10k leaked"             || echo "ok   no p10k"
```
Expected: seven `ok` lines, zero `FAIL`. The last three assert the deviations from the spec actually happened.

- [ ] **Step 6: Verify the git config**

```bash
cat /tmp/hm/home-files/.config/git/config
```
Expected: contains `name = Anton`, `email = vdovenkoantono@gmail.com`, `rebase = true`, `autoSetupRemote = true`, and a `gh auth git-credential` helper with no `/Users/User/.local/bin` prefix.

- [ ] **Step 7: Commit**

```bash
git add home/shell.nix home/git.nix home/default.nix
git commit -m "Configure zsh, prompt and git through home-manager"
```

---

### Task 8: Dotfile symlinks and mutable VS Code settings

**Files:**
- Create: `home/files.nix`
- Modify: `home/default.nix` (add the import)

**Interfaces:**
- Consumes: the `dotfiles/` tree from Task 2.
- Produces: the deployed file tree that `scripts/doctor.sh` checks in Task 10.

- [ ] **Step 1: Write `home/files.nix`**

Ghostty, AeroSpace, tmux, oh-my-posh and git-ignore are symlinked read-only. The two VS Code files are *copied* by an activation script and only when absent, so VS Code's own settings UI keeps working and never gets clobbered.

```nix
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

    "ghostty/shaders" = {
      source = "${dotfiles}/ghostty/shaders";
      recursive = true;
    };

    "oh-my-posh/config.json".source = "${dotfiles}/oh-my-posh/config.json";
    "oh-my-posh/config-tmux.json".source = "${dotfiles}/oh-my-posh/config-tmux.json";
    "git/ignore".source = "${dotfiles}/git/ignore";
  };

  # VS Code settings are copied, not symlinked, so the settings UI can write to
  # them. Copy only when absent — never overwrite live edits. `just sync-vscode`
  # is the path back into the repo.
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
```

- [ ] **Step 2: Add the import to `home/default.nix`**

Add `./files.nix` to the `imports` list, which becomes:

```nix
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./files.nix
  ];
```

- [ ] **Step 3: Build and verify every deployed file matches the repo byte-for-byte**

```bash
nix build .#darwinConfigurations.VdovenkoAnton.config.home-manager.users.User.home.activationPackage -o /tmp/hm
H=/tmp/hm/home-files
diff "$H/.aerospace.toml"                  dotfiles/aerospace/aerospace.toml   && echo "ok   aerospace"
diff "$H/.tmux.conf"                       dotfiles/tmux/tmux.conf             && echo "ok   tmux"
diff "$H/.config/ghostty/config"           dotfiles/ghostty/config             && echo "ok   ghostty"
diff -r "$H/.config/ghostty/shaders"       dotfiles/ghostty/shaders            && echo "ok   shaders"
diff "$H/.config/oh-my-posh/config.json"   dotfiles/oh-my-posh/config.json     && echo "ok   omp"
diff "$H/.config/oh-my-posh/config-tmux.json" dotfiles/oh-my-posh/config-tmux.json && echo "ok   omp-tmux"
diff "$H/.config/git/ignore"               dotfiles/git/ignore                 && echo "ok   git ignore"
```
Expected: seven `ok` lines, no diff output.

- [ ] **Step 4: Verify the shader count survived**

Run: `ls /tmp/hm/home-files/.config/ghostty/shaders | wc -l`
Expected: `36` — 35 shader files plus the `theme` directory. A count of 1 means `recursive = true` was omitted and the whole directory collapsed into a single symlink.

- [ ] **Step 5: Verify VS Code files are NOT in the symlink tree**

Run: `ls "/tmp/hm/home-files/Library/Application Support/Code/User/" 2>&1`
Expected: `No such file or directory`. If those files appear here they are symlinked rather than copied, which breaks the settings UI — move them back into the activation script.

- [ ] **Step 6: Commit**

```bash
git add home/files.nix home/default.nix
git commit -m "Symlink dotfiles and copy VS Code settings mutably"
```

---

### Task 9: Pinned tmux plugins

**Files:**
- Create: `home/tmux-plugins.nix`
- Modify: `home/default.nix` (add the import)

**Interfaces:**
- Consumes: nothing.
- Produces: six plugin directories at the paths `dotfiles/tmux/tmux.conf` already references.

- [ ] **Step 1: Write `home/tmux-plugins.nix` with placeholder hashes**

Revisions are the exact commits running on the source machine. Hashes are unknown until Nix computes them, so start with `lib.fakeHash` and let the build report the real values.

```nix
{ pkgs, lib, ... }:
let
  src = { owner, repo, rev, hash }:
    pkgs.fetchFromGitHub { inherit owner repo rev hash; };

  tpm = src {
    owner = "tmux-plugins"; repo = "tpm";
    rev = "99469c4a9b1ccf77fade25842dc7bafbc8ce9946";
    hash = lib.fakeHash;
  };
  sensible = src {
    owner = "tmux-plugins"; repo = "tmux-sensible";
    rev = "25cb91f42d020f675bb0a2ce3fbd3a5d96119efa";
    hash = lib.fakeHash;
  };
  resurrect = src {
    owner = "tmux-plugins"; repo = "tmux-resurrect";
    rev = "cff343cf9e81983d3da0c8562b01616f12e8d548";
    hash = lib.fakeHash;
  };
  continuum = src {
    owner = "tmux-plugins"; repo = "tmux-continuum";
    rev = "0698e8f4b17d6454c71bf5212895ec055c578da0";
    hash = lib.fakeHash;
  };
  yank = src {
    owner = "tmux-plugins"; repo = "tmux-yank";
    rev = "acfd36e4fcba99f8310a7dfb432111c242fe7392";
    hash = lib.fakeHash;
  };
  # Not TPM-managed on the source machine: tmux.conf loads it with a bare `run`
  # line and no `set -g @plugin`, so `prefix + I` would never install it.
  catppuccin = src {
    owner = "catppuccin"; repo = "tmux";
    rev = "8b0b9150f9d7dee2a4b70cdb50876ba7fd6d674a";
    hash = lib.fakeHash;
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
```

- [ ] **Step 2: Add the import to `home/default.nix`**

The `imports` list becomes:

```nix
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./files.nix
    ./tmux-plugins.nix
  ];
```

- [ ] **Step 3: Run the build to harvest the real hashes**

Run: `nix build .#darwinConfigurations.VdovenkoAnton.config.home-manager.users.User.home.activationPackage -o /tmp/hm 2>&1 | grep -A2 'hash mismatch'`

Expected: failures reporting `specified: sha256-AAAA…` and `got: sha256-<real>`. Nix reports one at a time, so this is a loop: copy the `got:` value into the matching plugin, rebuild, repeat until all six are filled in. Replace every `lib.fakeHash` — none may remain.

- [ ] **Step 4: Verify no placeholder hashes survive**

Run: `grep -c 'fakeHash' home/tmux-plugins.nix`
Expected: `0`.

- [ ] **Step 5: Verify all six plugins land at the right paths**

```bash
nix build .#darwinConfigurations.VdovenkoAnton.config.home-manager.users.User.home.activationPackage -o /tmp/hm
H=/tmp/hm/home-files
for p in tpm tmux-sensible tmux-resurrect tmux-continuum tmux-yank; do
  test -e "$H/.tmux/plugins/$p" && echo "ok   $p" || echo "MISSING $p"
done
test -f "$H/.config/tmux/plugins/catppuccin/catppuccin.tmux" \
  && echo "ok   catppuccin (entrypoint present)" \
  || echo "MISSING catppuccin entrypoint"
test -f "$H/.tmux/plugins/tpm/tpm" && echo "ok   tpm entrypoint" || echo "MISSING tpm entrypoint"
```
Expected: seven `ok` lines. The catppuccin check targets `catppuccin.tmux` specifically because that is the exact file `tmux.conf`'s `run` line invokes — a directory that exists but lacks it would still render a broken status bar.

- [ ] **Step 6: Commit**

```bash
git add home/tmux-plugins.nix home/default.nix
git commit -m "Declare six tmux plugins at pinned revisions"
```

---

### Task 10: justfile, doctor and VS Code sync

**Files:**
- Create: `justfile`
- Create: `scripts/doctor.sh`
- Create: `scripts/sync-vscode.sh`

**Interfaces:**
- Consumes: `config.homebrew.brewfile` (Task 4), the `dotfiles/` tree (Task 2), the deployed home tree (Tasks 8–9).
- Produces: the `just doctor` acceptance criterion named in the spec.

- [ ] **Step 1: Write the `justfile`**

```make
default:
    @just --list

# Build and apply the configuration.
switch:
    sudo darwin-rebuild switch --flake .#VdovenkoAnton

# Build without applying. Run this before switch.
build:
    nix build .#darwinConfigurations.VdovenkoAnton.system --no-link

# Evaluate the flake for errors.
check:
    nix flake check

# Update all flake inputs.
update:
    nix flake update

# Install the VS Code extensions listed in dotfiles/vscode/extensions.txt.
sync-vscode-extensions:
    #!/usr/bin/env bash
    set -euo pipefail
    while read -r ext; do
      [ -z "$ext" ] && continue
      echo "installing $ext"
      code --install-extension "$ext" --force
    done < dotfiles/vscode/extensions.txt

# Copy live VS Code settings back into the repo, ready to commit.
sync-vscode:
    ./scripts/sync-vscode.sh

# Check the running machine against what this repo declares.
doctor:
    ./scripts/doctor.sh
```

Note the leading indentation in `justfile` recipes must be consistent; `just` accepts spaces.

- [ ] **Step 2: Write `scripts/doctor.sh`**

```bash
#!/usr/bin/env bash
# Check the running machine against what this repo declares.
# Exits non-zero if anything is missing.
set -uo pipefail

cd "$(dirname "$0")/.."

FAIL=0
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }

echo "== Homebrew casks =="
BREWFILE=$(nix eval --raw .#darwinConfigurations.VdovenkoAnton.config.homebrew.brewfile 2>/dev/null)
if [ -n "$BREWFILE" ]; then
  installed=$(brew list --cask 2>/dev/null)
  # $BREWFILE holds the Brewfile CONTENT, not a store path — nix-darwin's
  # config.homebrew.brewfile evaluates to the text itself.
  # Process substitution, not a pipe: a piped `while` runs in a subshell and
  # its FAIL=1 would be discarded, making every cask failure invisible.
  while read -r c; do
    short="${c##*/}"
    if echo "$installed" | grep -qx "$short"; then ok "$short"; else bad "$short not installed"; fi
  done < <(printf '%s\n' "$BREWFILE" | grep '^cask "' | sed 's/^cask "\([^"]*\)".*/\1/')
else
  bad "could not evaluate the Brewfile"
fi

echo "== CLI tools on PATH =="
for c in bat eza fd rg jq gh nvim tmux go node uv mise gcloud aws lazygit zoxide oh-my-posh yazi; do
  command -v "$c" >/dev/null 2>&1 && ok "$c" || bad "$c not on PATH"
done

echo "== Dotfile symlinks resolve into the nix store =="
check_link() {
  if [ ! -e "$1" ]; then bad "$1 missing"
  elif readlink "$1" | grep -q '^/nix/store'; then ok "$1"
  else warn "$1 exists but is not a store symlink"; fi
}
check_link "$HOME/.aerospace.toml"
check_link "$HOME/.tmux.conf"
check_link "$HOME/.config/ghostty/config"
check_link "$HOME/.config/oh-my-posh/config.json"
check_link "$HOME/.config/oh-my-posh/config-tmux.json"

echo "== tmux plugins =="
for p in tpm tmux-sensible tmux-resurrect tmux-continuum tmux-yank; do
  [ -e "$HOME/.tmux/plugins/$p" ] && ok "$p" || bad "$p missing"
done
[ -f "$HOME/.config/tmux/plugins/catppuccin/catppuccin.tmux" ] \
  && ok "catppuccin" || bad "catppuccin missing (status bar will render raw placeholders)"

echo "== Ghostty shaders =="
n=$(ls "$HOME/.config/ghostty/shaders" 2>/dev/null | wc -l | tr -d ' ')
[ "$n" -ge 35 ] && ok "$n shaders" || bad "only $n shaders found, expected 36"

echo "== VS Code extensions =="
if command -v code >/dev/null 2>&1; then
  live=$(code --list-extensions 2>/dev/null | sort)
  want=$(sort dotfiles/vscode/extensions.txt)
  missing=$(comm -13 <(echo "$live") <(echo "$want"))
  if [ -z "$missing" ]; then ok "all declared extensions installed"
  else
    while read -r m; do [ -n "$m" ] && bad "extension $m not installed"; done <<< "$missing"
  fi
else
  bad "code CLI not on PATH"
fi

echo "== VS Code settings drift =="
V="$HOME/Library/Application Support/Code/User"
for f in settings.json keybindings.json; do
  if [ ! -f "$V/$f" ]; then bad "$f missing"
  elif diff -q "$V/$f" "dotfiles/vscode/$f" >/dev/null 2>&1; then ok "$f matches the repo"
  else warn "$f differs from the repo — run 'just sync-vscode' to capture it"; fi
done

echo
[ "$FAIL" -eq 0 ] && echo "doctor: all checks passed" || echo "doctor: failures above"
exit "$FAIL"
```

- [ ] **Step 3: Write `scripts/sync-vscode.sh`**

```bash
#!/usr/bin/env bash
# Copy live VS Code settings back into the repo, ready to commit.
set -euo pipefail

cd "$(dirname "$0")/.."

V="$HOME/Library/Application Support/Code/User"

cp "$V/settings.json"    dotfiles/vscode/settings.json
cp "$V/keybindings.json" dotfiles/vscode/keybindings.json
code --list-extensions > dotfiles/vscode/extensions.txt

echo "Synced into dotfiles/vscode/. Changes:"
git --no-pager diff --stat dotfiles/vscode/
```

- [ ] **Step 4: Make the scripts executable and check they parse**

```bash
chmod +x scripts/doctor.sh scripts/sync-vscode.sh
bash -n scripts/doctor.sh      && echo "doctor.sh parses"
bash -n scripts/sync-vscode.sh && echo "sync-vscode.sh parses"
```
Expected: both parse lines print.

- [ ] **Step 5: Verify `just` recipes resolve**

```bash
nix run nixpkgs#just -- --list
nix run nixpkgs#just -- build
```
Expected: `--list` shows all seven recipes; `build` completes without error.

- [ ] **Step 6: Run doctor and read the output honestly**

Run: `nix run nixpkgs#just -- doctor; echo "exit=$?"`

Expected **before activation**: failures for casks and symlinks, because nothing has been applied to this machine yet. That is correct behaviour and proves the checks actually test something. What must NOT happen is doctor reporting all-clear on an unactivated machine — if it does, the checks are vacuous and need fixing.

- [ ] **Step 7: Commit**

```bash
git add justfile scripts
git commit -m "Add just recipes, doctor checks and VS Code sync script"
```

---

### Task 11: Documentation

**Files:**
- Modify: `README.md`
- Create: `MANUAL.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write `README.md`**

```markdown
# macOS setup

Declarative macOS configuration for `VdovenkoAnton`: nix-darwin for the system,
home-manager for the user environment, Homebrew for GUI apps.

## Fresh machine

```sh
xcode-select --install
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/AntonVdovenko/macos-setup ~/Workspace/Nix/macos_setup
cd ~/Workspace/Nix/macos_setup
nix run nix-darwin -- switch --flake .#VdovenkoAnton
just sync-vscode-extensions
just doctor
```

Then work through `MANUAL.md` for the things Nix cannot do.

## Day to day

| Command | Does |
| --- | --- |
| `just switch` | Build and apply the configuration |
| `just build` | Build without applying — run before `switch` |
| `just check` | Evaluate the flake for errors |
| `just update` | Update flake inputs |
| `just doctor` | Check this machine against what the repo declares |
| `just sync-vscode` | Copy live VS Code settings back into the repo |
| `just sync-vscode-extensions` | Install the extensions listed in `dotfiles/vscode/extensions.txt` |

## Layout

- `darwin/` — root-level: macOS defaults, Homebrew casks, Touch ID
- `home/` — user config expressed in Nix: packages, zsh, git, symlinks
- `dotfiles/` — verbatim configs, edited in their native syntax
- `hosts/` — per-machine literals; one file per Mac

## Adding an app

GUI app: add the cask to `darwin/homebrew.nix`. CLI tool: add the package to
`home/packages.nix`. Then `just switch`.

**Do not set `homebrew.onActivation.cleanup = "zap"`.** This repo deliberately
does not declare every app in `/Applications`, and `zap` uninstalls anything
undeclared.
```

- [ ] **Step 2: Write `MANUAL.md`**

```markdown
# Manual steps

Everything a fresh `just switch` cannot do. Roughly 15 minutes.

## Credentials

- [ ] Copy `~/.ssh/` from the old machine or your password manager, then
      `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*`
- [ ] `gh auth login`
- [ ] `gcloud auth login` and `gcloud config set project <project>`
- [ ] Copy `~/.aws/credentials` and `~/.aws/config`
- [ ] Copy `~/.kube/config` if you need cluster access

## Apps needing a sign-in

- [ ] Slack, Telegram, Discord, WhatsApp, Claude, ChatGPT
- [ ] VS Code — sign in to Settings Sync if you use it

## Apps this repo does not install

Installed by hand on the old machine and deliberately left undeclared. Install
whichever you still want:

Microsoft Office, Xcode, Adobe Acrobat, OneDrive, Grammarly, Obsidian, Steam,
AdGuard, Clash Verge, AWS VPN Client, VLC, Folx, Google Chrome, Safari
extensions, Portal, Wallspace.

## macOS settings not managed here

- [ ] Apple ID and iCloud sign-in
- [ ] Keyboard layouts and input sources
- [ ] Displays, Night Shift, hot corners
- [ ] Grant Accessibility permission to AeroSpace on first launch
      (System Settings → Privacy & Security → Accessibility)

## First-run notes

- Ghostty needs a restart after the fonts land, or it falls back to a system font.
- tmux plugins are already installed by Nix — `prefix + I` is NOT needed.
- Saved tmux sessions do not transfer; continuum starts saving fresh.
```

- [ ] **Step 3: Verify the README commands match the justfile**

```bash
grep -oE '^[a-z-]+:' justfile | tr -d ':' | sort > /tmp/recipes
for r in switch build check update doctor sync-vscode sync-vscode-extensions; do
  grep -qx "$r" /tmp/recipes && echo "ok   $r" || echo "FAIL $r documented but missing"
done
```
Expected: seven `ok` lines.

- [ ] **Step 4: Commit**

```bash
git add README.md MANUAL.md
git commit -m "Document bootstrap, daily commands and manual steps"
```

---

### Task 12: Publish to GitHub

**Files:**
- None created.

**Interfaces:**
- Consumes: the complete repo.
- Produces: `github.com/AntonVdovenko/macos-setup`.

- [ ] **Step 1: Final secret sweep before anything leaves the machine**

```bash
git ls-files | xargs grep -lIE '(BEGIN [A-Z ]*PRIVATE KEY|gho_[A-Za-z0-9]|ghp_[A-Za-z0-9]|aws_secret_access_key)' 2>/dev/null \
  || echo "NO SECRETS FOUND"
```
Expected: `NO SECRETS FOUND`. Anything else stops the task.

- [ ] **Step 2: Confirm the repo name and visibility with the user**

Creating a GitHub repo is outward-facing and not silently reversible. Ask before running Step 3: name (`macos-setup`) and **public or private**. Do not assume.

- [ ] **Step 3: Create the remote and push**

```bash
gh repo create macos-setup --<visibility> --source=. --remote=origin --push
```
Substitute the visibility the user chose. Do not invent a default.

- [ ] **Step 4: Verify the push landed**

```bash
gh repo view AntonVdovenko/macos-setup --json name,visibility,defaultBranchRef
git log --oneline origin/main | head -5
```
Expected: the repo exists with the chosen visibility, and `origin/main` carries the full commit history.

---

### Task 13: Activate on this Mac — CANCELLED

**The user instructed on 2026-08-02 that this work must not change anything on their Mac. This task is cancelled. Do not execute it.** It is kept below only as a record of what activation would involve, for whenever they choose to adopt the config — most likely on the new machine rather than this one.

The consequence to be honest about: Tasks 1–12 prove the configuration *builds* and that its outputs are byte-correct. They cannot prove it *activates* cleanly, because activation is the one thing being withheld. First activation on the new Mac may surface issues — most likely Homebrew declining to adopt an already-installed app, or a home-manager refusal to overwrite an existing dotfile (mitigated by `backupFileExtension`).

<details>
<summary>Original task, retained for reference</summary>

### Task 13: Activate (OPTIONAL — requires explicit user approval)

**Files:**
- None created.

**Interfaces:**
- Consumes: the complete repo.
- Produces: proof the configuration actually works, rather than merely building.

Everything up to here proves the config *builds*. Only activation proves it *works*. But activating replaces this machine's live `~/.zshrc`, `~/.tmux.conf`, `~/.aerospace.toml` and Ghostty config with store symlinks, installs 15 casks, and applies macOS defaults. It is reversible but disruptive.

**Do not run this task without the user explicitly asking for it.**

- [ ] **Step 1: Get explicit approval**

Present what changes: the dotfiles above become symlinks (originals saved with a `.hm-backup` suffix), casks install for apps already present by other means, and the Dock/appearance defaults reapply. Ask whether to proceed.

- [ ] **Step 2: Back up the live dotfiles independently of home-manager**

```bash
mkdir -p ~/dotfiles-backup-2026-08-02
cp ~/.zshrc ~/.zprofile ~/.zshenv ~/.tmux.conf ~/.aerospace.toml ~/dotfiles-backup-2026-08-02/
cp -R ~/.config/ghostty ~/dotfiles-backup-2026-08-02/ghostty
ls -la ~/dotfiles-backup-2026-08-02
```
Expected: the listing shows every file. Do not proceed until it does.

- [ ] **Step 3: Build first, switch second**

```bash
nix run nixpkgs#just -- build && echo "BUILD OK"
```
Expected: `BUILD OK`. A failing build must never be followed by a switch.

- [ ] **Step 4: Activate**

```bash
sudo nix run nix-darwin -- switch --flake .#VdovenkoAnton
```
Expected: activation output ending without `error:`. Homebrew will install casks for apps already installed by hand — brew adopts most of them, but may report a conflict for an app it did not install. Record any such conflict rather than forcing it.

- [ ] **Step 5: Verify with doctor in a fresh shell**

```bash
zsh -lc 'cd ~/Workspace/Nix/macos_setup && just doctor'
```
Expected: `doctor: all checks passed`. Any failure is real — report it with the output rather than declaring success.

- [ ] **Step 6: Verify the shell by hand**

```bash
zsh -lc 'which gcloud; which gh; alias ll; echo $PATH | tr ":" "\n" | head -5'
```
Expected: `gcloud` and `gh` both resolve into `/nix/store`, `ll` is `eza --long -a`.

- [ ] **Step 7: Commit any fixes the activation forced**

```bash
git add -A
git commit -m "Fix issues surfaced by first activation"
git push
```

---

## Notes for the implementer

- **The build/eval distinction is the safety property.** `nix build` and `nix eval` construct store paths and change nothing about the running machine. `darwin-rebuild switch` is the only command that mutates it, and it appears exactly once, in the gated Task 13.
- **Hash harvesting in Task 9 is expected to fail repeatedly.** That is the workflow, not a problem. Nix reports one mismatched hash per build.
- **When a check fails, report the output.** Several verification steps are designed to fail before their implementation lands. Distinguish "failed as expected" from "failed unexpectedly" and never paper over the second.

</details>
