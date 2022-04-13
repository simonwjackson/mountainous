#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

sudo nixos-rebuild -v switch --impure --flake .#

popd > /dev/null
