#!/bin/sh

pushd ~/nix-config > /dev/null

./apply-system.sh && ./apply-users.sh

popd > /dev/null
