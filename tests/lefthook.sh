#!/usr/bin/env bash
# Exercise the actual pre-push runner without pushing or installing Git hooks.
set -euo pipefail
config=$(realpath "$1")
guard=$(realpath "$2")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir -p "$HOME" "$work/repo/scripts"
cd "$work/repo"
git init -q
git -c user.name=HookTest -c user.email=hook-test@example.invalid commit -q --allow-empty -m fixture --no-verify
cp "$config" lefthook.yml
cp "$guard" scripts/check-flake-inputs.sh
printf '%s\n' 'inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";' > flake.nix
printf '%s\n' '{"nodes":{}}' > flake.lock
lefthook run pre-push --no-auto-install --force
for url in 'path:/tmp/local' 'path:./local'; do
  printf 'inputs.local.url = "%s";\n' "$url" > flake.nix
  if lefthook run pre-push --no-auto-install --force > output 2>&1; then
    echo "FAIL: accepted $url" >&2
    exit 1
  fi
  grep -q 'Refusing to push' output
done
printf '%s\n' 'inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";' > flake.nix
printf '%s\n' '{"nodes":{"local":{"locked":{"type":"path","path":"/tmp/local"}}}}' > flake.lock
if lefthook run pre-push --no-auto-install --force > output 2>&1; then
  echo 'FAIL: accepted local path lock entry' >&2
  exit 1
fi
grep -q 'Refusing to push' output
printf '%s\n' 'LEFTHOOK_PRE_PUSH_PASSED: valid refs pass; local URL and lock inputs fail'
