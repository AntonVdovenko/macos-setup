host := "macbook"

default:
    @just --list

# Build and apply the configuration.
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f hosts/local.nix ] || { echo "run ./scripts/configure-host.sh first" >&2; exit 1; }
    if command -v darwin-rebuild >/dev/null 2>&1; then
      sudo darwin-rebuild switch --flake path:.#{{host}}
    else
      # Bootstrap: darwin-rebuild is installed by the first activation.
      sudo /nix/var/nix/profiles/default/bin/nix run nix-darwin -- switch --flake path:.#{{host}}
    fi

# Build without applying. Run this before switch.
build:
    @test -f hosts/local.nix || { echo "run ./scripts/configure-host.sh first" >&2; exit 1; }
    nix build path:.#darwinConfigurations.{{host}}.system --no-link

# Evaluate the flake for errors.
check:
    @test -f hosts/local.nix || { echo "run ./scripts/configure-host.sh first" >&2; exit 1; }
    nix flake check path:.

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
