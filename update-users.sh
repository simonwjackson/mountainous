#!/bin/sh

pushd ~/nix-config
nix-channel --update
popd
