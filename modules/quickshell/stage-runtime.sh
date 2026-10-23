#!/usr/bin/env bash
# Stage the same runtime tree used by bars.nix, preserving relative imports.
# Development only: callers generate notification-schema.js after this step.
set -euo pipefail
source_dir=$(realpath "${1:?pass the Quickshell source directory}")
stage_dir=${2:?pass a fresh staging directory}
mkdir -p "$stage_dir"
while IFS= read -r -d '' file; do
  relative=${file#"$source_dir"/}
  case "$relative" in
    *.qml|*.js|themes.json|icons/*|themes/*)
      mkdir -p "$stage_dir/$(dirname "$relative")"
      ln -s "$file" "$stage_dir/$relative"
      ;;
  esac
done < <(find "$source_dir" \
  -type d \( -name notification-dev -o -name builder-dev -o -name theme-dev \) -prune -o \
  -type f ! -name '*.test.js' ! -name '*.py' ! -name '*.sh' -print0)
