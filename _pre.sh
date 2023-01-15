#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

set -e

if ! op account get; then
  eval "$(op signin)"
fi
