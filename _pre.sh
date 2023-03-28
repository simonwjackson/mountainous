#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

set -e

[[ $(op account get) ]] || eval "$(op signin)"
