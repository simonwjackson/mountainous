#!/bin/sh

pushd ~/nix-config > /dev/null

sudo nixos-rebuild switch --flake .#

popd > /dev/null
