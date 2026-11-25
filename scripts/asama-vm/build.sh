#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export NIX_SSHOPTS='-F /dev/null'
builder=ssh-ng://simon@aka
vm=$(nix build --store "$builder" --no-link --print-out-paths .#nixosConfigurations.asama-vm.config.system.build.vm)
# The design guest is a local build, not a signed cache release. Transfer it
# between the two authenticated SSH stores, not via Zao's store.
nix copy --no-check-sigs --from "$builder" --to ssh-ng://simon@myoko "$vm"
printf '%s\n' "$vm"
