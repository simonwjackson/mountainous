#!/bin/sh

set -e

sudo nix-collect-garbage -d
sudo nixos-rebuild switch
