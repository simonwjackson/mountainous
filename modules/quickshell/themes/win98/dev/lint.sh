#!/usr/bin/env bash
# qmllint for the Win98 theme, with the types resolved as Quickshell
# resolves them at run time.
#
#   QMLLINT=qmllint QML_PATHS=<dir>:<dir> modules/quickshell/themes/win98/dev/lint.sh <shell dir>
#
# Quickshell writes the qmldirs itself (a singleton is a file with
# `pragma Singleton`), so the source tree has none and qmllint alone cannot
# see Theme or Win98Tokens as singletons. This stages the shell root as the
# module `qs` with Theme.qml and the theme as `qs.themes.win98`, writes the
# qmldirs Quickshell would, and lints there. Any warning fails, except
# PanelWindow's uncreatable-type in the gallery (Quickshell's own idiom,
# reported on every PanelWindow in this repo).
set -euo pipefail

shell_dir=$(realpath "${1:?shell dir (modules/quickshell)}")
qmllint=${QMLLINT:-qmllint}
work=$(mktemp -d "${TMPDIR:-/tmp}/win98-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT

theme="$work/qs/themes/win98"
mkdir -p "$theme"
cp "$shell_dir/Theme.qml" "$work/qs/"
printf 'module qs\nsingleton Theme 1.0 Theme.qml\n' > "$work/qs/qmldir"
cp "$shell_dir"/themes/win98/Win98*.qml "$theme/"
{
  echo "module qs.themes.win98"
  for f in "$theme"/Win98*.qml; do
    n=$(basename "$f" .qml)
    if grep -q '^pragma Singleton' "$f"; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi
  done
} > "$theme/qmldir"

args=(-I "$work")
IFS=: read -r -a paths <<< "${QML_PATHS:-}"
for p in "${paths[@]}"; do [ -n "$p" ] && args+=(-I "$p"); done

cd "$theme"
"$qmllint" "${args[@]}" Win98*.qml > "$work/report" 2>&1 || true
files=$(ls Win98*.qml | wc -l)
allowed='Win98Gallery.qml:[0-9]+:[0-9]+: Type PanelWindow is not creatable'
if grep -E '^Warning' "$work/report" | grep -vE "$allowed" | grep -q .; then
  cat "$work/report" >&2
  echo "WIN98_QMLLINT_WARNINGS" >&2
  exit 1
fi
echo "WIN98_QMLLINT_CLEAN ($files files)"
