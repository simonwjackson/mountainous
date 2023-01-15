#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

set -e

source ./_pre.sh

op run --env-file=.env -- sudo -E nixos-rebuild --impure -v switch --flake .#
