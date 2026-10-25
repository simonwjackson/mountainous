#!/usr/bin/env bash
# The same XDG registration as hjem, in an isolated graphical session.
set -euo pipefail
export LC_ALL=C.UTF-8
export HOME="$TMPDIR/home"
export XDG_RUNTIME_DIR="$TMPDIR/runtime"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/quickshell" "$XDG_STATE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
ln -s "$PYXAMP/etc/xdg/quickshell/pyxamp" "$XDG_CONFIG_HOME/quickshell/pyxamp"
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
unset DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
labwc > "$TMPDIR/compositor.log" 2>&1 &
pids+=("$!")
for _ in {1..100}; do
  for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [[ -S "$socket" ]]; then export WAYLAND_DISPLAY="${socket##*/}"; break 2; fi
  done
  sleep 0.1
done
: "${WAYLAND_DISPLAY:?Headless compositor did not start}"
"$PYXAMP/bin/pyxamp-daemon" > "$TMPDIR/daemon.log" 2>&1 &
pids+=("$!")
"$PYXAMP/bin/pyxamp" > "$TMPDIR/face.log" 2>&1 &
pids+=("$!")
ready=0
for _ in {1..100}; do
  if "$QS" -c pyxamp ipc call pyxamp describe > "$TMPDIR/before.json" 2>/dev/null \
      && jq -e '.link == "connected"' "$TMPDIR/before.json" >/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done
if [[ "$ready" != 1 ]]; then
  cat "$TMPDIR/daemon.log" "$TMPDIR/face.log" "$TMPDIR/before.json" >&2
  exit 1
fi
# The shortcut uses the packaged runtime, never the desktop's older qs.
"$PYXAMP/bin/pyxamp" ipc call pyxamp toggle
"$QS" -c pyxamp ipc call pyxamp describe > "$TMPDIR/after.json"
jq -e --slurp '.[0].shown != .[1].shown' "$TMPDIR/before.json" "$TMPDIR/after.json"
# Standard XDG lookup also works for the desktop's qs IPC client. It never
# launches that older runtime as the face.
"$DESKTOP_QS" -c pyxamp ipc call pyxamp toggle
"$QS" -c pyxamp ipc call pyxamp describe > "$TMPDIR/restored.json"
jq -e --slurp '.[0].shown == .[1].shown' "$TMPDIR/before.json" "$TMPDIR/restored.json"
echo PYXAMP_DESKTOP_IPC_PASSED
