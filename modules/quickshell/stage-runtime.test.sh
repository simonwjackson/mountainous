#!/usr/bin/env bash
set -euo pipefail
source_dir=$(realpath "${1:-modules/quickshell}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash "$source_dir/stage-runtime.sh" "$source_dir" "$work/runtime"
for file in shell.qml Theme.qml hensou-host.js panels/StorageHealth.qml panels/NotificationCentre.qml \
  themes/platinum/picker-plan.js themes/platinum/previews/light.png icons/builder.svg; do
  test -L "$work/runtime/$file"
  cmp "$source_dir/$file" "$work/runtime/$file"
done
for file in notification-dev builder-dev theme-dev stage-runtime.sh stage-runtime.test.sh \
  bar-plan.test.js notification-schema-js.sh; do
  test ! -e "$work/runtime/$file"
done
# Nested icons are runtime assets too, regardless of the theme's name.
mkdir -p "$work/source/themes/sample/icons" "$work/source/theme-dev"
printf '<svg/>\n' > "$work/source/themes/sample/icons/mark.svg"
printf 'not runtime\n' > "$work/source/theme-dev/Fixture.qml"
bash "$source_dir/stage-runtime.sh" "$work/source" "$work/assets"
test -L "$work/assets/themes/sample/icons/mark.svg"
test ! -e "$work/assets/theme-dev"
echo RUNTIME_STAGING_TESTS_PASSED
