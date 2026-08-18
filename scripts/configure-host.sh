#!/usr/bin/env bash
# Adapt the tracked host profile to the macOS account running this script.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: this setup supports macOS only" >&2
  exit 1
fi

username=$(id -un)
home_directory=${HOME:?HOME is not set}

case "$username" in
  (*[!A-Za-z0-9._-]*|'')
    echo "error: unsupported account name: $username" >&2
    exit 1
    ;;
esac

case "$home_directory" in
  (*[\"\\'|'\&]*|'')
    echo "error: unsupported home-directory path: $home_directory" >&2
    exit 1
    ;;
esac

if [ ! -d "$home_directory" ]; then
  echo "error: home directory does not exist: $home_directory" >&2
  exit 1
fi

case "$(uname -m)" in
  arm64) system=aarch64-darwin ;;
  x86_64) system=x86_64-darwin ;;
  *)
    echo "error: unsupported Mac architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

host_file=hosts/vdovenko-mbp.nix
sed -i '' -E \
  -e "s|^  username = \".*\";|  username = \"$username\";|" \
  -e "s|^  homeDirectory = \".*\";|  homeDirectory = \"$home_directory\";|" \
  -e "s|^  system = \".*\";|  system = \"$system\";|" \
  "$host_file"

echo "Configured $host_file:"
echo "  account:      $username"
echo "  home:         $home_directory"
echo "  architecture: $system"

for program in /nix/var/nix/profiles/default/bin/nix /opt/homebrew/bin/brew; do
  if [ -x "$program" ]; then
    echo "  found:        $program"
  else
    echo "  missing:      $program" >&2
    missing=1
  fi
done

if [ "${missing:-0}" -ne 0 ]; then
  echo "Install the missing prerequisite above, then rerun this script." >&2
  exit 1
fi
