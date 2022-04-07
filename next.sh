#!/bin/sh

pushd ~/nix-config
./update.sh \
&& ./apply.sh
popd
