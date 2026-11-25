#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
vm=$(nix build --no-link --print-out-paths .#nixosConfigurations.asama-vm.config.system.build.vm)
NIX_SSHOPTS='-F /dev/null' nix copy --to ssh-ng://simon@myoko "$vm"
printf '%s\n' "$vm"
