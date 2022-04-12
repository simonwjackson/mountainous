#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

sudo nixos-rebuild switch --flake .#

popd > /dev/null
