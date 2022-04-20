#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

function cleanup () {
  popd > /dev/null
}

if [ -n "$(git status --porcelain)" ]; then
  cleanup
  echo "Commit your changes"
  exit 1
else
  sudo nixos-rebuild \
    -v switch \
    --profile-name "$(git log -1 --pretty=%B | sed "s/[^[:alnum:]-]/-/g")" \
    --flake '.#'
  cleanup
fi
