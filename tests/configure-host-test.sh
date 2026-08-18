#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

test_repo="$test_tmp/repo"
test_home="$test_tmp/home"
mkdir -p "$test_repo/scripts" "$test_repo/hosts" "$test_home"
cp "$repo_root/scripts/configure-host.sh" "$test_repo/scripts/configure-host.sh"

HOME="$test_home" "$test_repo/scripts/configure-host.sh" >/dev/null

local_host="$test_repo/hosts/local.nix"
test -f "$local_host"
grep -F 'configuration = "macbook";' "$local_host" >/dev/null
grep -F "username = \"$(id -un)\";" "$local_host" >/dev/null
grep -F "homeDirectory = \"$test_home\";" "$local_host" >/dev/null

case "$(uname -m)" in
  arm64) expected_system=aarch64-darwin ;;
  x86_64) expected_system=x86_64-darwin ;;
esac
grep -F "system = \"$expected_system\";" "$local_host" >/dev/null

grep -Fx 'hosts/local.nix' "$repo_root/.gitignore" >/dev/null
test -z "$(git -C "$repo_root" ls-files hosts/local.nix)"
