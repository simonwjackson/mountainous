#!/usr/bin/env bash
# A private headless session for the Win98 Desktop harness (development and
# checks; never delivered). Sourced, not run:
#
#   . modules/quickshell/theme-dev/win98/session.sh <shell dir> <work dir> [WxH]
#   w98 set tb-normal; w98 theme light; shot out.png; session_stop
#
# Stages the shell with harness.qml as shell.qml, starts sway's headless
# backend (pixman, no DRM output) at WxH physical px, scale 1.5, in private
# runtime, state, config and cache directories, and starts Quickshell. The
# live desktop and its Quickshell are never touched.
#
# Needs on PATH: sway, swaymsg, grim, qs. FONTCONFIG_FILE must list W95FA
# Grid (the Desktop uses the packaged family, not a FontLoader).

session_shell=$(realpath "${1:?shell dir}")
session_work=$(realpath -m "${2:?work dir}")
session_res=${3:-2880x1800}
session_here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p "$session_work"
rm -f "$session_work/commands.log"
export XDG_RUNTIME_DIR="$session_work/run" XDG_STATE_HOME="$session_work/state" XDG_CONFIG_HOME="$session_work/config"
export XDG_CACHE_HOME="$session_work/cache" XDG_DATA_HOME="$session_work/data"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$session_work/bin"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK

# Stand-ins for the helpers the data owners and the Desktop run.
for helper in oci-egress-status storage-health-status nix-builder-gate; do
  printf '#!/bin/sh\nexec sleep 100000\n' > "$session_work/bin/$helper"
done
for helper in mountainous-brightness hyprctl hypr-scale notify-send wpctl; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/commands.log"\n' "$helper" "$session_work" > "$session_work/bin/$helper"
done
cat > "$session_work/bin/desktop-theme" <<EOF
#!/bin/sh
echo "desktop-theme \$*" >> "$session_work/commands.log"
dir="\$XDG_STATE_HOME/mountainous"
put() { printf '%s\n' "\$2" > "\$dir/\$1.new" && mv "\$dir/\$1.new" "\$dir/\$1"; }
case "\$1" in
  apply) put theme-name "\$2"; put theme "\$3"; put theme-extra "\$4" ;;
  set) put theme-name "\$2" ;;
  picker) exit 0 ;;
esac
EOF
chmod +x "$session_work/bin/"*
export PATH="$session_work/bin:$PATH"

stage="$session_work/shell"
rm -rf "$stage"
mkdir -p "$stage"
cp -r "$session_shell"/. "$stage"/
chmod -R u+w "$stage"
rm -rf "$stage/win98-dev"
mkdir -p "$stage/win98-dev"
cp "$session_here"/states.js "$stage/win98-dev/"
cp "$session_here/harness.qml" "$stage/shell.qml"
[ -n "${SESSION_SCHEMA:-}" ] && cp "$SESSION_SCHEMA" "$stage/notification-schema.js"
printf 'win98\n' > "$XDG_STATE_HOME/mountainous/theme-name"
printf 'light\n' > "$XDG_STATE_HOME/mountainous/theme"

cat > "$session_work/sway.conf" <<EOF
output HEADLESS-1 resolution $session_res scale 1.5 bg #202830 solid_color
default_border none
seat seat0 hide_cursor 100000
EOF
session_pids=()
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$session_work/sway.conf" >"$session_work/sway.log" 2>&1 &
session_pids+=($!)
for _ in $(seq 100); do
  sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1 || true)
  [ -n "$sock" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY="$sock"
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1)

USER=simon HOSTNAME=myoko QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
  qs -p "$stage/shell.qml" --no-color >"$session_work/qs.log" 2>&1 &
session_pids+=($!)

# A virtual keyboard that stays (when wtype is on PATH): a headless seat
# has none, and without one no surface ever has the keyboard, so focus
# rings never draw. Each later wtype types through the same seat.
if command -v wtype >/dev/null; then
  wtype -s 100000000 &
  session_pids+=($!)
fi

w98() { qs -p "$stage/shell.qml" ipc call w98 "$@" 2>/dev/null; }
for _ in $(seq 100); do w98 current >/dev/null && break; sleep 0.2; done

shot() { grim -o HEADLESS-1 "$1"; }
session_stop() {
  for pid in "${session_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
}
