#!/usr/bin/env bash
# Check the running machine against what this repo declares.
# Exits non-zero if anything is missing.
set -uo pipefail

cd "$(dirname "$0")/.."

# System and Home Manager profiles may not be on PATH in a non-login shell.
export PATH="/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

HOSTCFG="macbook"

FAIL=0
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }

echo "== Homebrew casks =="
# NOTE: config.homebrew.brewfile evaluates to the Brewfile CONTENT, not a store
# path. Do not try to cat it.
if [ ! -f hosts/local.nix ]; then
  bad "hosts/local.nix missing; run ./scripts/configure-host.sh"
  BREWFILE=""
else
  BREWFILE=$(nix eval --raw "path:.#darwinConfigurations.${HOSTCFG}.config.homebrew.brewfile" 2>/dev/null)
fi
if [ -n "$BREWFILE" ]; then
  installed=$(brew list --cask 2>/dev/null)
  # Process substitution, not a pipe: a piped `while` runs in a subshell and its
  # FAIL=1 would be discarded, making every cask failure invisible.
  while read -r c; do
    short="${c##*/}"
    if echo "$installed" | grep -qx "$short"; then ok "$short"; else bad "$short not installed"; fi
  done < <(printf '%s\n' "$BREWFILE" | grep '^cask "' | sed 's/^cask "\([^"]*\)".*/\1/')
else
  bad "could not evaluate the Brewfile"
fi

echo "== CLI tools on PATH =="
for c in bat eza fd rg jq gh nvim tmux go node uv mise gcloud aws lazygit zoxide oh-my-posh yazi just; do
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
# Checked by entrypoint, not directory: tmux.conf invokes this exact file, and a
# directory without it still renders a broken status bar.
[ -f "$HOME/.config/tmux/plugins/catppuccin/catppuccin.tmux" ] \
  && ok "catppuccin" || bad "catppuccin missing (status bar will render raw placeholders)"

echo "== Ghostty shaders =="
n=$(ls "$HOME/.config/ghostty/shaders" 2>/dev/null | wc -l | tr -d ' ')
[ "${n:-0}" -ge 35 ] && ok "$n shaders" || bad "only ${n:-0} shaders found, expected 36"

echo "== VS Code extensions =="
if command -v code >/dev/null 2>&1; then
  missing=$(comm -13 <(code --list-extensions 2>/dev/null | sort) <(sort dotfiles/vscode/extensions.txt))
  if [ -z "$missing" ]; then
    ok "all declared extensions installed"
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
if [ "$FAIL" -eq 0 ]; then echo "doctor: all checks passed"; else echo "doctor: failures above"; fi
exit "$FAIL"
