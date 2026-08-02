# macOS setup repo — design

Date: 2026-08-02
Status: approved

## Goal

A git repo that rebuilds this Mac's working environment on a new machine with one
command, so that a fresh laptop feels like this one within an hour: same terminal,
same prompt, same window manager bindings, same editor, same CLI tools.

The target is "close enough to start working immediately", not a byte-identical
clone. Application state that lives outside config files — iCloud data, app
licences, browser profiles, credentials — is explicitly out of scope and handled
by a manual checklist.

## Source machine

Captured 2026-08-02 from `VdovenkoAnton`, macOS 26.5.2, arm64, user `User`.

| Layer | Current state |
| --- | --- |
| Shell | zsh + oh-my-zsh (`git` plugin only), zsh-autosuggestions, zsh-syntax-highlighting, zoxide |
| Prompt | oh-my-posh, two themes: `config.json`, `config-tmux.json` (switched on `$TMUX`) |
| Terminal | Ghostty — Catppuccin Latte/Frappé auto-switch, JetBrainsMono Nerd Font 14, 35 GLSL shaders |
| Window manager | AeroSpace (`~/.aerospace.toml`, config-version 2, alt+hjkl, 31 persistent workspaces, zero gaps) |
| Multiplexer | tmux — prefix `C-a`, vim panes, TPM (sensible/resurrect/continuum/yank), Catppuccin Frappé |
| Editor | VS Code — 31 extensions, Dark Modern, MesloLGL Nerd Font Mono, indent-rainbow palette |
| Packages | 33 Homebrew formulae, 5 casks; ~25 GUI apps installed by hand |

## Decisions

These were settled during brainstorming and are not open for re-litigation during
implementation.

1. **Faithfulness: same feel, clean plumbing.** Visual and interaction behaviour is
   preserved exactly. Fragile machine-local plumbing is replaced with declared
   equivalents. See "Deliberate deviations".
2. **Config style: hybrid.** Hand-tuned configs stay as verbatim files in
   `dotfiles/` and are symlinked by home-manager. Nix expresses only mechanical
   concerns: package lists, git config, environment, aliases, shell wiring, macOS
   defaults, casks.
3. **App scope: dev & windowing, plus AI & comms, plus Hidden Bar.** Cursor is
   excluded. Productivity/Office, network/VPN and media apps are excluded.
4. **VS Code: mutable settings plus a sync script.** home-manager does not own
   `settings.json`. Extensions install from the marketplace via a checked-in list.
5. **Secrets: excluded entirely.** Nothing encrypted, nothing committed. A
   `MANUAL.md` checklist covers restoration. The repo is safe to make public.
6. **Wiring: one flake.** home-manager runs as a nix-darwin module, so a single
   `darwin-rebuild switch` applies system and user config together.

## Architecture

Three layers, split by what they own rather than by topic:

- `darwin/` — anything requiring root: nix daemon settings, fonts, Touch ID for
  sudo, macOS system defaults, the Homebrew cask list.
- `home/` — user-level configuration expressed as Nix: package lists, git,
  environment and PATH, aliases, zsh wiring, and the symlink declarations.
- `dotfiles/` — bytes copied from the source machine, edited in their native
  syntax and never translated into Nix.

`.zshrc` is the one config that is *generated*, not copied. home-manager's
`programs.zsh` owns it — oh-my-zsh with the `git` plugin, the autosuggestions and
syntax-highlighting plugins, the `ll` alias, the `$TMUX`-conditional oh-my-posh
init, and `zoxide init`. Copying the current `.zshrc` verbatim would re-import the
`~/Downloads` gcloud path and the Framework Python alias that decision 1 removes.

Per-machine values (hostname, username, architecture) live in exactly one file
under `hosts/`. Adding a second Mac is one new file plus one line in `flake.nix`.

### Deployment targets

| Repo path | Target | Mechanism |
| --- | --- | --- |
| `dotfiles/ghostty/config` | `~/.config/ghostty/config` | symlink |
| `dotfiles/ghostty/shaders/` | `~/.config/ghostty/shaders/` | symlink (recursive) |
| `dotfiles/aerospace/aerospace.toml` | `~/.aerospace.toml` | symlink |
| `dotfiles/tmux/tmux.conf` | `~/.tmux.conf` | symlink |
| `dotfiles/oh-my-posh/*.json` | `~/.config/oh-my-posh/` | symlink |
| `dotfiles/vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | **copy** (writable) |
| `dotfiles/vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | **copy** (writable) |
| `dotfiles/vscode/extensions.txt` | — | consumed by `just sync-vscode-extensions` |
| pinned tmux plugins (see below) | `~/.tmux/plugins/`, `~/.config/tmux/plugins/` | fetched by Nix, symlinked |

Symlinked files are read-only Nix store paths; editing them means editing the repo
and rebuilding. The two VS Code files are copied precisely so they stay writable —
see "The VS Code sync loop".

### tmux plugins

`tmux.conf` is deployed verbatim, but it is inert without its plugins, and those
are not self-installing. Two distinct mechanisms are in play on the source
machine:

- Four plugins are declared with `set -g @plugin` and installed by TPM into
  `~/.tmux/plugins/`.
- Catppuccin is **not** TPM-managed. It is loaded by a bare
  `run ~/.config/tmux/plugins/catppuccin/catppuccin.tmux` line with no `@plugin`
  declaration, so `prefix + I` does not install it. On a fresh machine that `run`
  line fails and the status bar renders raw `#{E:@catppuccin_status_*}`
  placeholders instead of a theme.

All six are therefore fetched by Nix at pinned revisions and placed at the exact
paths `tmux.conf` already references. This keeps `tmux.conf` verbatim, removes
`prefix + I` from the bootstrap, and pins plugin versions — TPM would otherwise
clone current `master` and give a new Mac newer plugins than this one.

| Plugin | Rev | Tag | Destination |
| --- | --- | --- | --- |
| catppuccin/tmux | `8b0b915` | latest | `~/.config/tmux/plugins/catppuccin` |
| tmux-plugins/tpm | `99469c4` | v3.0.0 | `~/.tmux/plugins/tpm` |
| tmux-plugins/tmux-sensible | `25cb91f` | v3.0.0 | `~/.tmux/plugins/tmux-sensible` |
| tmux-plugins/tmux-resurrect | `cff343c` | v4.0.0 | `~/.tmux/plugins/tmux-resurrect` |
| tmux-plugins/tmux-continuum | `0698e8f` | v3.1.0 | `~/.tmux/plugins/tmux-continuum` |
| tmux-plugins/tmux-yank | `acfd36e` | v2.3.0 | `~/.tmux/plugins/tmux-yank` |

TPM is still deployed because `tmux.conf` ends with `run '~/.tmux/plugins/tpm/tpm'`
and that line stays verbatim. TPM loads plugins already present on disk without
writing to them, so read-only store paths are fine; only `prefix + I` writes, and
it is no longer needed.

Saved session layouts under `~/.local/share/tmux/resurrect` are runtime state, not
configuration, and are not carried over. A new Mac starts with no restored
sessions.

### Repo layout

```
macos_setup/
├── flake.nix                 # inputs + darwinConfigurations."VdovenkoAnton"
├── flake.lock                # pinned input versions
├── justfile                  # switch / build / update / sync-vscode / doctor
├── README.md
├── MANUAL.md                 # post-install checklist
├── hosts/
│   └── vdovenko-mbp.nix
├── darwin/
│   ├── default.nix
│   ├── homebrew.nix
│   └── defaults.nix
├── home/
│   ├── default.nix
│   ├── packages.nix
│   ├── shell.nix
│   ├── git.nix
│   └── files.nix
└── dotfiles/
    ├── ghostty/config
    ├── ghostty/shaders/          # 35 .glsl files + theme dir
    ├── aerospace/aerospace.toml
    ├── tmux/tmux.conf
    ├── oh-my-posh/config.json
    ├── oh-my-posh/config-tmux.json
    └── vscode/
        ├── settings.json
        ├── keybindings.json
        └── extensions.txt
```

### Flake inputs

- `nixpkgs` — `github:nixos/nixpkgs/nixpkgs-unstable`
- `nix-darwin` — with `inputs.nixpkgs.follows = "nixpkgs"`
- `home-manager` — with `inputs.nixpkgs.follows = "nixpkgs"`

`follows` on both keeps a single nixpkgs evaluation, which avoids duplicate store
paths and version skew between the system and user halves.

## Package allocation

### nixpkgs (CLI)

awscli2, bat, duf, eza, fd, ffmpeg, fzf, gh, glances, go, google-cloud-sdk, htop,
jq, lazydocker, lazygit, libpq, minikube, mise, neovim, nodejs, nushell,
oh-my-posh, pandoc, postgresql_14, ripgrep, staticcheck, tldr, tmux, uv, yazi,
zoxide, zsh-autosuggestions, zsh-syntax-highlighting.

zsh itself is not installed from nixpkgs. The system zsh remains the login shell;
home-manager only writes its configuration. This avoids editing `/etc/shells` and
the associated login-shell failure mode.

### Homebrew casks

ghostty, visual-studio-code, dbeaver-community, orbstack,
`nikitabobko/tap/aerospace`, rectangle, hidden-bar, font-jetbrains-mono,
font-meslo-lg-nerd-font, claude, chatgpt, slack, telegram, discord, whatsapp.

Required tap: `nikitabobko/tap`.

`homebrew.onActivation.cleanup = "none"`. The source machine has roughly 25
undeclared apps in `/Applications` (Office, Xcode, Adobe Acrobat, Steam, AdGuard,
Clash Verge, VLC, Folx, Grammarly, OneDrive and others). The `"zap"` setting would
uninstall all of them on first activation. This must not be changed without first
declaring every app that should survive.

### Dropped

| Package | Reason |
| --- | --- |
| powerlevel10k | Installed but inactive — the source line in `.zshrc` is commented out |
| starship | Installed with a full config but never initialised in `.zshrc` |
| libmagic, libyaml | Transitive build dependencies, not called directly |
| Cursor | Excluded by decision 3 |
| syncthing | Falls in the excluded network/media group |

## Deliberate deviations from the source machine

These four are the only behavioural differences. Everything else — prompt,
colours, fonts, keybindings, aliases, tmux prefix, AeroSpace bindings, Ghostty
shaders — is preserved verbatim.

| Source machine | This repo | Rationale |
| --- | --- | --- |
| `gcloud` sourced from `~/Downloads/google-cloud-sdk` | `google-cloud-sdk` from nixpkgs | A `~/Downloads` path cannot survive a machine move |
| `alias python=` pinned to Framework Python 3.12 | `uv` and `mise` manage Python; no alias | The alias breaks unless that installer is run by hand first |
| `gh`, `code`, `lsd`, `uv` dropped into `~/.local/bin` | declared packages on PATH | Hand-placed binaries are not reproducible |
| `.p10k.zsh`, `.config/starship.toml`, dead source lines | removed | Inert on the source machine |

## Additions

Two things not present on the source machine, approved during brainstorming:

- Touch ID for sudo (`security.pam.services.sudo_local.touchIdAuth = true`).
- macOS defaults captured declaratively: dock autohide, dock tile size 64, Dark
  appearance. These match current state; no unset defaults are introduced.

## Bootstrap

```sh
xcode-select --install
curl -L https://install.determinate.systems/nix | sh -s -- install   # NixOS/nix-installer fork
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/AntonVdovenko/macos-setup ~/Workspace/Nix/macos_setup
cd ~/Workspace/Nix/macos_setup
nix run nix-darwin -- switch --flake .#VdovenkoAnton
just sync-vscode-extensions
open MANUAL.md
```

Upstream Nix is used rather than Determinate Nix. Determinate manages
`/etc/nix/nix.conf` itself, which conflicts with nix-darwin's `nix.*` options and
requires `nix.enable = false` — an extra failure mode for a first setup.

Expected wall clock: 30–40 minutes, dominated by downloads. Subsequent rebuilds
use `just switch`.

## Verification

Three levels, none of which is "it built, so it works":

1. `nix flake check` — the flake evaluates without error.
2. `just build` — full dry build with no activation. Run before every switch.
3. `just doctor` — asserts what Nix cannot:
   - every declared cask is present in `/Applications`
   - every declared CLI resolves on `PATH`
   - every symlinked target in the deployment table resolves into the Nix store
   - all six tmux plugin directories exist, including the non-TPM Catppuccin one
   - the two copied VS Code files differ from `dotfiles/vscode/` only in ways you
     have not yet synced — reported as a diff, not an error
   - the installed VS Code extension set matches `extensions.txt`

`just doctor` is the check that catches drift between the repo and reality, and is
the acceptance criterion for the implementation being complete.

## The VS Code sync loop

`settings.json` and `keybindings.json` are copied into place by an activation
script rather than symlinked, so VS Code can still write to them through its own
settings UI. `just sync-vscode` copies them back into `dotfiles/vscode/` and
regenerates `extensions.txt` from `code --list-extensions`, ready to commit.

This trades automatic enforcement for a usable settings UI. Drift between the repo
and the live files is expected and is surfaced by `just doctor`, not prevented.

## Out of scope

Handled by `MANUAL.md`, not by this repo:

SSH private keys; AWS, kube and gcloud credentials; `gh auth login`; application
sign-ins and licences; iCloud and Apple ID state; browser profiles; the ~25
undeclared `/Applications` entries; saved tmux session layouts under
`~/.local/share/tmux/resurrect`.

## Risks

- **Homebrew is declarative, not reproducible.** Casks always resolve to latest,
  so a new Mac receives newer app versions than the source machine. Accepted.
- **aarch64-darwin build breakage.** nixpkgs occasionally marks a darwin build
  broken. Fallback is a Homebrew formula with a comment recording why.
- **macOS point upgrades.** Historically these have broken the Nix store volume
  mount. Known-fix problem; budget time for it roughly annually.
- **Cask name drift.** `telegram` installs Telegram Desktop, whereas the source
  machine runs "Telegram Lite" from the App Store. Minor difference in build,
  flagged rather than worked around.

## Publication

The repo is initialised locally, committed as work proceeds, and pushed to
`github.com/AntonVdovenko/macos-setup` once the implementation is complete and
`just doctor` passes. Because decision 5 keeps all secrets out, either visibility
is safe; visibility is confirmed with the user immediately before the remote is
created, since creating it is not reversible from the user's side without effort.
