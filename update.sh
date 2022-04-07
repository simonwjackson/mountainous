#!/bin/sh

pushd ~/nix-config
./update-system.sh \
&& ./update-users.sh
popd
