#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

set -e

sudo nix-collect-garbage -d
nix-collect-garbage -d
echo "Cleaning up /nix/store"
sudo nix-store --optimise
