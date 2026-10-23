#!/usr/bin/env bash
# qmllint for the Win98 theme, with the types resolved as Quickshell
# resolves them at run time.
#
#   QMLLINT=qmllint QML_PATHS=<dir>:<dir> modules/quickshell/themes/win98/dev/lint.sh <shell dir>
#
# Quickshell writes the qmldirs itself (a singleton is a file with
# `pragma Singleton`), so the source tree has none and qmllint alone cannot
# see Theme or Win98Tokens as singletons. The theme's QML is flat in the
# shell root (Quickshell cannot load QML from subfolders at run time), so
# this stages the shell root (its QML, scripts, panels and theme assets) and
# the gallery (dev/) as the module `qs`, writes the qmldir Quickshell would,
# and lints every Win98*.qml there.
set -euo pipefail

shell_dir=$(realpath "${1:?shell dir (modules/quickshell)}")
qmllint=${QMLLINT:-qmllint}
work=$(mktemp -d "${TMPDIR:-/tmp}/win98-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT

theme="$work/qs"
mkdir -p "$theme"
cp -r "$shell_dir"/. "$theme"/
chmod -R u+w "$theme"
cp "$shell_dir/themes/win98/dev/Win98Gallery.qml" "$theme/"
# The schema module is generated at build time; an empty stand-in is enough
# for the linter, which only resolves the import.
[ -f "$theme/notification-schema.js" ] || printf '.pragma library\n' > "$theme/notification-schema.js"
{
  echo "module qs"
  for f in "$theme"/*.qml; do
    n=$(basename "$f" .qml)
    [ "$n" = shell ] && continue
    if grep -q '^pragma Singleton' "$f"; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi
  done
} > "$theme/qmldir"

args=(-I "$work")
IFS=: read -r -a paths <<< "${QML_PATHS:-}"
for p in "${paths[@]}"; do [ -n "$p" ] && args+=(-I "$p"); done

cd "$theme"
"$qmllint" "${args[@]}" Win98*.qml > "$work/report" 2>&1 || true
files=$(ls Win98*.qml | wc -l)
allowed='Win98[A-Za-z]*.qml:[0-9]+:[0-9]+: Type PanelWindow is not creatable'
if grep -E '^Warning' "$work/report" | grep -vE "$allowed" | grep -q .; then
  cat "$work/report" >&2
  echo "WIN98_QMLLINT_WARNINGS" >&2
  exit 1
fi
echo "WIN98_QMLLINT_CLEAN ($files files)"
