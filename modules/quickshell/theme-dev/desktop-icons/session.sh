#!/usr/bin/env bash
# A private headless session for the desktop icon harness (development and
# checks; never delivered). Sourced, not run:
#
#   . modules/quickshell/theme-dev/desktop-icons/session.sh <shell dir> <work dir> [WxH]
#   desk current; theme platinum light; shot out.png; session_stop
#
# Stages modules/quickshell with harness.qml as shell.qml, starts sway's
# headless backend at WxH physical px and scale 1.5 (SESSION_SCALE), in
# private runtime, state, config and cache directories, a desktop provider
# on $XDG_RUNTIME_DIR/hensou/desktop.sock, and Quickshell. The live desktop
# and its Quickshell are never touched.
#
# The provider is Hensou's hensou-desktop-stub when DESKTOP_STUB names it,
# else provider.js (same fixtures, plus the stress sets). Needs sway, grim,
# qs and node on PATH; FONTCONFIG_FILE with ChicagoFLF and W95FA Grid;
# XDG_DATA_DIRS with the desktop-art icon themes.

session_shell=$(realpath "${1:?shell dir}")
session_work=$(realpath -m "${2:?work dir}")
session_res=${3:-2880x1800}
session_here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p "$session_work"
export XDG_RUNTIME_DIR="$session_work/run" XDG_STATE_HOME="$session_work/state" XDG_CONFIG_HOME="$session_work/config"
export XDG_CACHE_HOME="$session_work/cache"
mkdir -p "$XDG_RUNTIME_DIR/hensou" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$session_work/bin"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK
# Nothing in a session may lock, suspend, power off or start an app.
for helper in hyprctl notify-send loginctl systemctl systemd-run desktop-theme; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/commands.log"\n' "$helper" "$session_work" > "$session_work/bin/$helper"
done
chmod +x "$session_work/bin/"*
export PATH="$session_work/bin:$PATH"

stage="$session_work/shell"
rm -rf "$stage"
mkdir -p "$stage"
cp -r "$session_shell"/. "$stage"/
chmod -R u+w "$stage"
cp "$session_here/harness.qml" "$stage/shell.qml"
printf '%s\n' "${SESSION_THEME:-platinum}" > "$XDG_STATE_HOME/mountainous/theme-name"
printf 'light\n' > "$XDG_STATE_HOME/mountainous/theme"
printf 'off\n' > "$XDG_STATE_HOME/mountainous/theme-extra"
printf 'off\n' > "$XDG_STATE_HOME/mountainous/theme-sounds"

cat > "$session_work/sway.conf" <<EOF
output HEADLESS-1 resolution $session_res scale ${SESSION_SCALE:-1.5} bg #202830 solid_color
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

provider_sock="$XDG_RUNTIME_DIR/hensou/desktop.sock"
provider_pid=""
# provider_start [stub|node] [fixture]
provider_start() {
  local kind=${1:-}
  [ -n "$kind" ] || { [ -n "${DESKTOP_STUB:-}" ] && kind=stub || kind=node; }
  if [ "$kind" = stub ]; then
    "$DESKTOP_STUB" "$provider_sock" >>"$session_work/provider.log" 2>&1 &
  else
    node "$session_here/provider.js" "$provider_sock" "$session_work/provider-messages.log" "${2:-stub}" >>"$session_work/provider.log" 2>&1 &
  fi
  provider_pid=$!
  session_pids+=($provider_pid)
  for _ in $(seq 50); do [ -S "$provider_sock" ] && break; sleep 0.1; done
}
provider_stop() {
  [ -n "$provider_pid" ] && kill "$provider_pid" 2>/dev/null || true
  wait "$provider_pid" 2>/dev/null || true
  provider_pid=""
  rm -f "$provider_sock"
}
provider_start "${SESSION_PROVIDER:-}" "${SESSION_FIXTURE:-stub}"

USER=simon HOSTNAME=myoko QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
  qs -p "$stage/shell.qml" --no-color >"$session_work/qs.log" 2>&1 &
session_pids+=($!)

# A virtual keyboard that stays, so a surface can hold the keyboard.
if command -v wtype >/dev/null; then
  wtype -s 100000000 &
  session_pids+=($!)
fi

desk() { qs -p "$stage/shell.qml" ipc call desk "$@" 2>/dev/null; }
theme() {
  printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme-name"
  printf '%s\n' "$2" > "$XDG_STATE_HOME/mountainous/theme"
  printf '%s\n' "${3:-off}" > "$XDG_STATE_HOME/mountainous/theme-extra"
}
# Until the session is live (or down) again.
desk_wait() {
  for _ in $(seq 60); do desk current | grep -q "\"kind\":\"${1:-live}\"" && return 0; sleep 0.1; done
  return 1
}
for _ in $(seq 100); do desk current >/dev/null && break; sleep 0.2; done

shot() { grim -o HEADLESS-1 "$1"; }
session_stop() {
  for pid in "${session_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
}
