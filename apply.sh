#!/bin/sh

set -e

pushd ~/nix-config > /dev/null

./apply-system.sh && ./apply-users.sh

popd > /dev/null
