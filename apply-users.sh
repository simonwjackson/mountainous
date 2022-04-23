#!/bin/sh

set -e

nix build .#homeConfigurations.$(whoami).activationPackage \
&& ./result/activate
