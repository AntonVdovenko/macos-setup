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
