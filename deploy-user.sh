#!/usr/bin/env bash
home-manager switch -b backup --flake ".#$(whoami)@$(hostname)"