#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

nix build .#homeConfigurations.$(whoami).activationPackage \
&& ./result/activate

popd > /dev/null
