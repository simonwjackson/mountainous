#!/usr/bin/env bash
# Keep machine-local flake inputs out of published revisions.
set -eu
bad=0
if [ -f flake.nix ] && grep -nE '(^|[^A-Za-z0-9_])url[[:space:]]*=[[:space:]]*"path:' flake.nix; then
  echo 'flake.nix references a local path input.'
  bad=1
fi
if [ -f flake.lock ] && grep -nE '"type"[[:space:]]*:[[:space:]]*"path"' flake.lock; then
  echo 'flake.lock has a path-type input.'
  bad=1
fi
if [ "$bad" -ne 0 ]; then
  echo 'Refusing to push: replace local path inputs with a git/github ref.' >&2
  echo 'Then run: nix flake update <input>' >&2
  exit 1
fi
