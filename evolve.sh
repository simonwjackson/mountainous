#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

./update.sh \
&& ./apply.sh

popd > /dev/null
