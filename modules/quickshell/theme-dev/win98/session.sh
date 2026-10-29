#!/usr/bin/env bash
# A private headless session for the Win98 Desktop harness (development and
# checks; never delivered). Sourced, not run:
#
#   . modules/quickshell/theme-dev/win98/session.sh <shell dir> <work dir> [WxH]
#   w98 set tb-normal; w98 theme light; shot out.png; session_stop
#
# Stages the shell with harness.qml as shell.qml, starts sway's headless
# backend (pixman, no DRM output) at WxH physical px, scale 1.5 (SESSION_SCALE), in private
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
# The session commands (Lock, Stand by, Restart, Shut down, Log off) and
# Launcher's scopes only log: nothing in a session may lock, suspend,
# reboot, power off, log out or start an app.
for helper in mountainous-brightness hyprctl hypr-scale notify-send wpctl loginctl systemctl systemd-run; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/commands.log"\n' "$helper" "$session_work" > "$session_work/bin/$helper"
done
# System Properties' NixOS line: the parity mock's values.
printf '#!/bin/sh\necho %s\n' "'{\"nixosVersion\":\"26.05.20260313.c06b4ae\"}'" > "$session_work/bin/nixos-version"
# The Fleet views' data: beszel-status answers from the mock's fixtures
# (beszel-stub.js); the harness picks the fixture (fleet-fixture).
cat > "$session_work/bin/beszel-status" <<EOF
#!/bin/sh
echo "beszel-status \$*" >> "$session_work/beszel.log"
exec node "$session_work/shell/win98-dev/beszel-stub.js" "\$@"
EOF
# The Layout control's command: page-layout-stub.js applies each call to
# the state file the harness writes ($XDG_RUNTIME_DIR/mountainous-page-layout.json).
cat > "$session_work/bin/mountainous-page-layout" <<EOF
#!/bin/sh
exec node "$session_work/shell/win98-dev/page-layout-stub.js" "\$@"
EOF
printf 'fake\n' > "$session_work/fake-token"
export BESZEL_MCP_TOKEN_FILE="$session_work/fake-token"
printf '%s\n' "${SESSION_FLEET:-unzen-problem}" > "$XDG_STATE_HOME/fleet-fixture"
cat > "$session_work/bin/desktop-theme" <<EOF
#!/bin/sh
echo "desktop-theme \$*" >> "$session_work/commands.log"
dir="\$XDG_STATE_HOME/mountainous"
put() { printf '%s\n' "\$2" > "\$dir/\$1.new" && mv "\$dir/\$1.new" "\$dir/\$1"; }
case "\$1" in
  apply) put theme-name "\$2"; put theme "\$3"; put theme-extra "\$4" ;;
  set) put theme-name "\$2" ;;
  rollback) if [ "\$(cat "\$dir/theme-name")" = "\$2" ]; then put theme-name "\$3"; fi ;;
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
cp "$session_here"/states.js "$session_here"/beszel-stub.js "$session_here"/fleet-fixtures.json "$session_here"/find-states.js \
  "$session_here"/page-layout-stub.js "$stage/win98-dev/"
cp "$session_here/OmniFixture.qml" "$session_here/LayoutFixture.qml" "$stage/"
cp "$session_here/harness.qml" "$stage/shell.qml"
[ -n "${SESSION_SCHEMA:-}" ] && cp "$SESSION_SCHEMA" "$stage/notification-schema.js"
printf '%s\n' "${SESSION_THEME:-win98}" > "$XDG_STATE_HOME/mountainous/theme-name"
printf 'light\n' > "$XDG_STATE_HOME/mountainous/theme"

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

# SESSION_COMPOSITOR=niri: the shell runs in a niri nested in the headless
# sway (software GL), because niri reports its layer-shell surfaces
# (niri msg layers) and sway does not. NIRI_SOCKET is exported for that.
if [ "${SESSION_COMPOSITOR:-sway}" = niri ]; then
  scale=${SESSION_SCALE:-1.5}
  mkdir -p "$session_work/niri"
  printf 'output "winit" { scale %s; }\nprefer-no-csd\nhotkey-overlay { skip-at-startup; }\n' "$scale" > "$session_work/niri/config.kdl"
  LIBGL_ALWAYS_SOFTWARE=1 niri -c "$session_work/niri/config.kdl" >"$session_work/niri.log" 2>&1 &
  session_pids+=($!)
  for _ in $(seq 100); do
    NIRI_SOCKET=$(ls "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -1 || true)
    [ -n "$NIRI_SOCKET" ] && break
    sleep 0.1
  done
  export NIRI_SOCKET
  WAYLAND_DISPLAY=$(basename "$NIRI_SOCKET" | sed -E 's/^niri\.(wayland-[0-9]+)\..*$/\1/')
  export WAYLAND_DISPLAY
fi

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
# Stops the session and everything it started, the helpers' stand-ins
# (sleep, node) that Quickshell spawned included: every process of this
# user whose environment names this session's runtime directory. None may
# outlive the session (they would keep inherited fds, a lock among them).
# The shell that runs the session and its ancestors are never stopped.
session_keep() {
  local p=$BASHPID
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do echo "$p"; p=$(awk '/^PPid:/ {print $2}' "/proc/$p/status" 2>/dev/null); done
  echo "$$"
}
session_procs() {
  local p keep
  keep=" $(session_keep | tr '\n' ' ') "
  for p in /proc/[0-9]*; do
    [[ "$keep" == *" ${p#/proc/} "* ]] && continue
    { tr '\0' '\n' < "$p/environ"; } 2>/dev/null | grep -qxF "XDG_RUNTIME_DIR=$session_work/run" && echo "${p#/proc/}"
  done
  return 0
}
session_stop() {
  for pid in "${session_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  local left
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    left=$(session_procs)
    [ -z "$left" ] && break
    kill $left 2>/dev/null || true
    sleep 0.2
  done
  left=$(session_procs)
  [ -n "$left" ] && kill -9 $left 2>/dev/null || true
  wait 2>/dev/null || true
}
