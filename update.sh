#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

nix flake update --extra-experimental-features nix-command --extra-experimental-features flakes
