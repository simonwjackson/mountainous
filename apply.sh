#!/bin/sh

pushd ~/nix-config
./apply-system.sh \
&& ./apply-users.sh
popd
