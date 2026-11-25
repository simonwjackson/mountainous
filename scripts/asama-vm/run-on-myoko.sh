#!/usr/bin/env bash
set -euo pipefail
vm=${1:?VM store path from build.sh}
[[ $vm == /nix/store/* && $vm != *[!a-zA-Z0-9/_+.-]* ]]
ssh -F /dev/null simon@myoko bash -s -- "$vm" <<'REMOTE'
set -eu
mkdir -p "$HOME/asama-vm"
systemd-run --user --collect --unit=asama-vm --working-directory="$HOME/asama-vm" "$1/bin/run-asama-vm-vm"
REMOTE
