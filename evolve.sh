#!/bin/sh

pushd ~/nix-config > /dev/null

./update.sh \
&& ./apply.sh

popd > /dev/null
