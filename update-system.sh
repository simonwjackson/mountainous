#!/bin/sh

pushd ~/nix-config
sudo nix-channel --update
popd
