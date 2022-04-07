#!/bin/sh

pushd ~/nix-config > /dev/null

nix build .#homeConfigurations.simonwjackson.activationPackage
./result/activate

popd > /dev/null
