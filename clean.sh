#! /usr/bin/env nix-shell
#! nix-shell -i bash

set -e

sudo nix-collect-garbage -d
sudo nixos-rebuild switch
