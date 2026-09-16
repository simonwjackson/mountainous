#!/usr/bin/env nix-shell
#! nix-shell -i bash -p lua5_4 coreutils gnugrep hyprland
# Verify the terminal overlay change without a machine to boot it on.
#
#   1. the flake evaluates and ridge renders a hyprland.lua
#   2. that rendered Lua is syntactically valid
#   3. Hyprland 0.56.2 itself accepts the config, which is what proves
#      hl.workspace_rule takes on_created_empty and that the dispatcher
#      hl.dsp.workspace.toggle_special exists. luac only proves syntax.
#   4. SUPER+T is bound exactly once
set -euo pipefail

cd "$(dirname "$0")"

attr='nixosConfigurations.ridge.config.hjem.users.simon.files.".config/hypr/hyprland.lua".text'
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

echo "== 1. evaluate the rendered config =="
nix eval --raw ".#$attr" >"$out/hyprland.lua"
printf '   rendered %s lines\n' "$(wc -l <"$out/hyprland.lua")"

echo "== 2. Lua syntax =="
luac -p "$out/hyprland.lua"
echo "   luac -p: OK"

echo "== 3. Hyprland --verify-config =="
# Runs the config through the real parser and Lua bindings. Exits non-zero and
# prints the offending call when a dispatcher or rule field does not exist.
if Hyprland --verify-config -c "$out/hyprland.lua" >"$out/verify.log" 2>&1; then
  echo "   accepted by Hyprland 0.56.2"
else
  echo "   REJECTED:"
  cat "$out/verify.log"
  exit 1
fi
grep -i "error\|invalid\|unknown" "$out/verify.log" && { echo "   FAIL: parser complained"; exit 1; }
echo "   no errors in parser output"

echo "== 4. SUPER+T bound exactly once =="
n=$(grep -c '" + T"' "$out/hyprland.lua" || true)
[ "$n" = "1" ] || { echo "   FAIL: expected 1, got $n"; exit 1; }
grep -n 'toggle_special\|special:term' "$out/hyprland.lua"

echo
echo "all checks passed"
