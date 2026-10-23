#!/usr/bin/env bash
# Screenshots of the remote-builder control in an isolated, headless sway
# session, driven by the fake nix-builder-gate next to this script.
# Development only; nothing installs this.
#
#   modules/quickshell/builder-dev/capture.sh [outdir] [hold]
#
# Same session as notification-dev/capture.sh: its own XDG_RUNTIME_DIR,
# state dir, session bus and notifyd harness, so the running desktop is never
# touched. The output matches myoko: a 2880x1800 panel at scale 1.5, so
# Quickshell lays out at 1920x1200. Each state gives a full-screen shot and
# crops of the bar and the panel, in panel pixels.
#
# Tools come from this flake's locked nixpkgs. Run it from the repo.
set -euo pipefail

if [ -z "${BUILDER_DEV_SHELL:-}" ]; then
  repo=$(git rev-parse --show-toplevel)
  export BUILDER_DEV_SHELL=1
  store() { nix --option builders '' build --no-link --print-out-paths --inputs-from "$repo" "nixpkgs#$1"; }
  BUILDER_DEV_FONTS=$(store dejavu_fonts)
  BUILDER_DEV_ICONS="$(store adwaita-icon-theme)/share:$(store hicolor-icon-theme)/share"
  QML2_IMPORT_PATH="$(store qt6.qtwebsockets)/lib/qt-6/qml"
  export BUILDER_DEV_FONTS BUILDER_DEV_ICONS QML2_IMPORT_PATH
  exec nix --option builders '' shell --inputs-from "$repo" \
    nixpkgs#sway nixpkgs#grim nixpkgs#quickshell nixpkgs#wtype nixpkgs#socat \
    nixpkgs#python3 nixpkgs#dbus \
    --command bash "$0" "$@"
fi

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(cd "$here/.." && pwd)
notification_dev="$shell_dir/notification-dev"
out=$(realpath -m "${1:-/tmp/builder-shots}")
mkdir -p "$out"

work=$(mktemp -d /tmp/builder-dev.XXXXXX)
export XDG_RUNTIME_DIR="$work/run"
export XDG_STATE_HOME="$work/state"
export XDG_CONFIG_HOME="$work/config"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK

export XDG_DATA_DIRS="$BUILDER_DEV_ICONS"
cat > "$work/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$BUILDER_DEV_FONTS/share/fonts</dir>
  <cachedir>$work/fontcache</cachedir>
  <alias><family>monospace</family><prefer><family>DejaVu Sans Mono</family></prefer></alias>
</fontconfig>
EOF
export FONTCONFIG_FILE="$work/fonts.conf"

cat > "$work/sway.conf" <<'EOF'
output HEADLESS-1 resolution 2880x1800 scale 1.5 bg #202830 solid_color
default_border none
EOF

# The fake gate, and quiet stand-ins for myoko's other bar helpers, so the
# control is drawn beside the neighbours it has on myoko.
bin="$work/bin"
mkdir -p "$bin"
ln -s "$here/nix-builder-gate" "$bin/nix-builder-gate"
cat > "$bin/oci-egress-status" <<'EOF'
#!/usr/bin/env bash
printf 'fuji\t12.4\t1270.1\t2950\nyari\t3.0\t307.2\t712\n'
EOF
cat > "$bin/storage-health-status" <<'EOF'
#!/usr/bin/env bash
printf 'zao\tok\tall mounts present\t%s\nunzen\tok\tall mounts present\t%s\n' "$(date +%s)" "$(date +%s)"
EOF
chmod +x "$bin"/*-status
# The same helpers without the gate, for the host that has none.
nogate="$work/bin-nogate"
mkdir -p "$nogate"
ln -s "$bin/oci-egress-status" "$bin/storage-health-status" "$nogate/"
export NIX_BUILDER_GATE_FAKE="$work/gate-world"
export NIX_BUILDER_GATE_STATE="$work/gate/state.json"
export OCI_EGRESS_ENABLED=1 STORAGE_HEALTH_ENABLED=1
gate() { PATH="$bin:$PATH" nix-builder-gate "$@"; }
gate fake reset

pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
pids+=($!)
sock=
for _ in $(seq 50); do
  for candidate in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$candidate" ]; then sock=${candidate##*/}; break; fi
  done
  [ -n "$sock" ] && break
  sleep 0.1
done
if [ -z "$sock" ]; then cat "$work/sway.log" >&2; exit 1; fi
export WAYLAND_DISPLAY="$sock"
for candidate in "$XDG_RUNTIME_DIR"/sway-ipc.*.sock; do
  if [ -S "$candidate" ]; then export SWAYSOCK="$candidate"; break; fi
done
: "${SWAYSOCK:?headless sway did not create its IPC socket}"

mkfifo "$work/pointer"
python3 "$notification_dev/pointer.py" 1920 1200 <"$work/pointer" >"$work/pointer.log" 2>&1 &
pids+=($!)
exec 7>"$work/pointer"
wtype -k F13 -s 86400000 -k F13 &
pids+=($!)

python3 "$notification_dev/notifyd-harness.py" \
  --socket "$XDG_RUNTIME_DIR/notify-sync/ui.sock" \
  --control "$work/ctl.sock" --assets "$work/assets" --scenario empty \
  >"$work/harness.log" 2>&1 &
pids+=($!)
sleep 0.5

stage="$work/shell"
mkdir -p "$stage"
bash "$shell_dir/stage-runtime.sh" "$shell_dir" "$stage"
bash "$shell_dir/notification-schema-js.sh" \
  "$shell_dir/../../packages/notify-sync/schema/ui-socket.v1.json" > "$stage/notification-schema.js"

theme() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme"; }
theme dark

start_shell() {
  QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
    PATH="$1:$PATH" dbus-run-session -- qs -p "$stage/shell.qml" >>"$work/qs.log" 2>&1 &
  shell_pid=$!
  pids+=("$shell_pid")
  for _ in $(seq 50); do
    qs -p "$stage/shell.qml" ipc show >/dev/null 2>&1 && break
    sleep 0.2
  done
  qs -p "$stage/shell.qml" ipc show >/dev/null 2>&1 || { cat "$work/qs.log" >&2; exit 1; }
  sleep 1.5
}
start_shell "$bin"

if [ "${2:-}" = hold ]; then
  cat > "$out/session.env" <<EOF
export XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR XDG_STATE_HOME=$XDG_STATE_HOME
export WAYLAND_DISPLAY=$WAYLAND_DISPLAY SWAYSOCK=$SWAYSOCK
export NIX_BUILDER_GATE_FAKE=$NIX_BUILDER_GATE_FAKE NIX_BUILDER_GATE_STATE=$NIX_BUILDER_GATE_STATE
export PATH=$bin:\$PATH SHELL_QML=$stage/shell.qml QS_LOG=$work/qs.log POINTER=$work/pointer
EOF
  echo "session up; source $out/session.env"
  wait
fi

ipc() { qs -p "$stage/shell.qml" ipc call "$@" 2>/dev/null || true; }
ptr() { printf '%s\n' "$*" >&7; sleep 0.25; }
key() { wtype -k "$1"; sleep 0.25; }
# Logical geometry of the bar's right end and of the panel.
W=1920
bar_box() { local x=$((W > 760 ? W - 760 : 0)); echo "$x,0 $((W - x))x28"; }
panel_box() { echo "$((W - 360)),0 360x${PANEL_H:-330}"; }
shot() {
  sleep "${2:-0.6}"
  grim "$out/full-$1.png"
  grim -g "$(bar_box)" "$out/bar-$1.png"
  if ipc builder current | grep -q "panel=true"; then
    grim -g "$(panel_box)" "$out/panel-$1.png"
  fi
  echo "$1  [$(ipc builder current)]"
}
world() { gate fake "$@" >/dev/null; sleep 0.4; }
panel() { ipc builder hide; sleep 0.2; ipc builder reveal; }

# The control's right end, found from the bar: the ▾ sits just left of NTF.
# The row is anchored right, so the ▾ keeps its place whatever the words;
# 1722 is inside the shortest text. Layout pixels at 1920 wide.
CONTROL_X=${CONTROL_X:-1722}
OPENER_X=${OPENER_X:-1744}

# ---- every gate state, dark, myoko's panel
world reset
shot home
world running 2;                                shot building
world running 0; world location away;           shot away
world location home; world power battery;       shot battery
world power ac; world location unknown;         shot no-network
world location away; gate set on >/dev/null;    shot choice-on
world location home; gate set off >/dev/null;   shot choice-off
world running 3;                                shot finishing
world running 1000000; world choice none;       shot stress-running
world running 0; world mode fail;               sleep 10; shot error-fail
world mode badjson;                             sleep 10; shot error-badjson
world mode ok;                                  sleep 10; shot recovered
# A gate that does not answer: the 5 s timeout, then a quiet error.
world mode slow;                                sleep 16; shot error-timeout
world mode ok;                                  sleep 10

# ---- the panel in each state; the keyboard opens it, so the ring shows
world reset;                                    panel; shot panel-home
world running 2;                                panel; shot panel-building
world running 0; gate set off >/dev/null;       panel; shot panel-choice-off
world running 3;                                panel; shot panel-finishing
world reset; world location away; gate set on >/dev/null; panel; shot panel-choice-on
world reset; world power battery;               panel; shot panel-battery
world reset; world location unknown;            panel; shot panel-no-network
world reset; world mode fail; sleep 10;         panel; shot panel-error
world mode ok; ipc builder hide; sleep 10

# ---- the keyboard: Tab walks, T toggles, D default, X stop, Esc closes
world reset; world running 2; panel; shot kbd-open 0.4
key Tab; shot kbd-tab-1 0.3
key Tab; shot kbd-tab-2 0.3
key t; shot kbd-t-toggled 1
key d; shot kbd-d-default 1
key x; shot kbd-x-stopped 1
key Escape; shot kbd-escaped 0.4

# ---- the pointer: hover, tooltip, press, one click, the opener, right-click
world reset
ptr move "$CONTROL_X" 13; shot hover 0.2
sleep 0.8; shot tooltip-home 0.1
gate set off >/dev/null; sleep 0.5; shot tooltip-choice-off 0.3
ptr move 900 600; world reset
ptr move "$CONTROL_X" 13; ptr down; shot pressed 0.1
ptr up; shot clicked-off 1
ptr click; shot clicked-on 1
ptr move "$OPENER_X" 13; shot opener-hover 0.2
ptr click; shot opener-opened 0.6
ptr move 900 600; ptr click; sleep 0.3
ptr move "$CONTROL_X" 13; ptr rclick; shot rclick-opened 0.6
ptr move 900 600; ptr click; sleep 0.3

# ---- a command in flight, and a command that fails
world reset; world mode set-slow
ptr move "$CONTROL_X" 13; ptr click; ptr move 900 600; shot pending 0.5
sleep 4.5
world reset; world mode set-slow; panel; sleep 0.6; key t; shot panel-pending 0.5
sleep 4.5; ipc builder hide
world reset; world mode set-fails
ptr move "$CONTROL_X" 13; ptr click; ptr move 900 600; shot action-failed 1
panel; shot panel-action-failed
ipc builder hide; world reset

# ---- light theme
theme light; sleep 0.6
world reset;                       shot light-home
world running 2;                   shot light-building
world running 0; gate set off >/dev/null; shot light-choice-off
panel; shot light-panel-choice-off; ipc builder hide
world reset; world location away;  shot light-away
world mode fail; sleep 10;         shot light-error
world mode ok; sleep 10
theme dark; sleep 0.6

# ---- SUPER+O hint lists R. It moves left of the controls when it must.
hint_shot() { ipc topbar reveal; sleep 0.3; grim -g "0,0 ${W}x28" "$out/bar-access-hint$1.png"; ipc topbar hide; }
hint_shot ""

# ---- other bar widths. Below 1400 the words shorten to "BLD"; below 560
# only the mark and the count remain. The mark and both targets
# stay at every width.
size() { swaymsg -q output HEADLESS-1 resolution "$1" scale 1.5; sleep 1.2; W=$2; }
size 2100x1800 1400
world reset;                         shot threshold-1400
size 2097x1800 1398
shot threshold-1398
hint_shot -1398
size 1200x1800 800
world reset;                         shot narrow-home
hint_shot -800
world running 2;                     shot narrow-building
world running 0; gate set off >/dev/null; shot narrow-choice-off
world mode fail; sleep 10;           shot narrow-error
world mode ok; sleep 10
world reset; world location away; panel; shot narrow-panel-away; ipc builder hide
size 840x1800 560
world reset;                         shot threshold-560
size 837x1800 558
shot threshold-558
world running 2;                     shot tiny-building
world running 0; gate set off >/dev/null; shot tiny-choice-off
world mode fail; sleep 10;           shot tiny-error
world mode ok; sleep 10
# A column: 400 x 1200.
size 600x1800 400
world reset; world running 2; panel; shot column-panel-building; ipc builder hide
# Strips, 1920 wide: the hint, the facts, the reason's extra lines, then the
# reason yield; below that the card scrolls and Tab keeps the focus in view.
for h in 340 300 260 220 219 180 179 140 110; do
  size "2880x$((h * 3 / 2))" 1920
  world reset; world running 2
  PANEL_H=$h panel; PANEL_H=$h shot "strip$h-panel-building"
done
key Tab; PANEL_H=110 shot strip110-panel-tab-to-stop 0.4
ipc builder hide
size 2880x1800 1920

# ---- the panel stays open, with its keyboard focus, across a resize
world reset; world running 2; panel; key Tab
size 1200x1800 800; shot resize-panel-kept 0.4
size 2880x1800 1920; ipc builder hide

# ---- no nix-builder-gate on PATH: nothing at all
kill "$shell_pid" 2>/dev/null || true
pkill -f -- "$stage/shell.qml" 2>/dev/null || true
sleep 1
start_shell "$nogate"
shot absent
hint_shot -absent

cp "$work/qs.log" "$out/qs.log"
echo "log: $out/qs.log"
