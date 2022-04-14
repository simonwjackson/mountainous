#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

sudo nixos-rebuild -v switch --flake .#

popd > /dev/null
