#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

sudo nix-collect-garbage -d

popd > /dev/null
