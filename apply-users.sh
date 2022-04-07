#!/bin/sh

pushd ~/nix-config
home-manager switch -f ./users/simonwjackson/home.nix
popd
