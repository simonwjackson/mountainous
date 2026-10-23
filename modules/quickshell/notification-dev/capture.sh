#!/usr/bin/env bash
# Screenshots of the notification view in an isolated, headless sway session.
# Development only; nothing installs this.
#
#   modules/quickshell/notification-dev/capture.sh [outdir] [hold]
#
# The session never touches the running desktop: it gets its own
# XDG_RUNTIME_DIR (so its own Wayland socket, Quickshell IPC and
# notify-sync/ui.sock), its own XDG_STATE_HOME (the theme file), and a notifyd
# harness. The real quickshell.service is not stopped, restarted or reached.
#
# The output matches myoko: a 2880x1800 panel at scale 1.5, so Quickshell
# lays out at 1920x1200. grim saves the panel's 2880x1800 pixels.
#
# Tools come from this flake's locked nixpkgs. Run it from the repo.
set -euo pipefail

if [ -z "${NOTIFICATION_DEV_SHELL:-}" ]; then
  repo=$(git rev-parse --show-toplevel)
  export NOTIFICATION_DEV_SHELL=1
  store() { nix --option builders '' build --no-link --print-out-paths --inputs-from "$repo" "nixpkgs#$1"; }
  NOTIFICATION_DEV_FONTS=$(store dejavu_fonts)
  NOTIFICATION_DEV_ICONS="$(store adwaita-icon-theme)/share:$(store hicolor-icon-theme)/share"
  # modules/browser.nix gives the real service QtWebSockets the same way.
  QML2_IMPORT_PATH="$(store qt6.qtwebsockets)/lib/qt-6/qml"
  export NOTIFICATION_DEV_FONTS NOTIFICATION_DEV_ICONS QML2_IMPORT_PATH
  exec nix --option builders '' shell --inputs-from "$repo" \
    nixpkgs#sway nixpkgs#grim nixpkgs#quickshell nixpkgs#wtype nixpkgs#socat \
    nixpkgs#python3 nixpkgs#dbus \
    --command bash "$0" "$@"
fi

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(cd "$here/.." && pwd)
out=$(realpath -m "${1:-/tmp/notification-shots}")
mkdir -p "$out"

work=$(mktemp -d /tmp/notification-dev.XXXXXX)
export XDG_RUNTIME_DIR="$work/run"
export XDG_STATE_HOME="$work/state"
export XDG_CONFIG_HOME="$work/config"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK

# myoko's fontconfig: DejaVu Sans Mono for monospace (modules/fonts.nix),
# and the Adwaita icons that modules/hyprland.nix installs.
dejavu=$NOTIFICATION_DEV_FONTS
export XDG_DATA_DIRS="$NOTIFICATION_DEV_ICONS"
cat > "$work/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>$dejavu/share/fonts</dir>
  <cachedir>$work/fontcache</cachedir>
  <alias><family>monospace</family><prefer><family>DejaVu Sans Mono</family></prefer></alias>
</fontconfig>
EOF
export FONTCONFIG_FILE="$work/fonts.conf"

cat > "$work/sway.conf" <<'EOF'
output HEADLESS-1 resolution 2880x1800 scale 1.5 bg #202830 solid_color
default_border none
EOF

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

# Input that lasts: a virtual pointer (pointer.py) and a virtual keyboard
# held open by a long wtype. One-shot devices vanish before Qt binds them.
mkfifo "$work/pointer"
python3 "$here/pointer.py" 1920 1200 <"$work/pointer" >"$work/pointer.log" 2>&1 &
pids+=($!)
exec 7>"$work/pointer"
wtype -k F13 -s 86400000 -k F13 &
pids+=($!)

python3 "$here/notifyd-harness.py" \
  --socket "$XDG_RUNTIME_DIR/notify-sync/ui.sock" \
  --control "$work/ctl.sock" --assets "$work/assets" --scenario empty \
  >"$work/harness.log" 2>&1 &
pids+=($!)
sleep 0.5

ctl() { printf '%s\n' "$*" | socat - "UNIX-CONNECT:$work/ctl.sock" >/dev/null; }
ipc() { qs -p "$stage/shell.qml" ipc call notifications "$@" 2>/dev/null || true; }
shot() { sleep "${2:-0.8}"; grim "$out/$1.png"; echo "$out/$1.png  [$(ipc current)]"; }
centre() { ipc hide; ctl "scenario $1"; sleep 0.4; ipc reveal; shot "$2"; }
popups() { ipc hide; ctl "scenario empty"; sleep 0.3; ctl "popups $1"; shot "$2" "${3:-0.8}"; }
size() { swaymsg -q output HEADLESS-1 resolution "$1" scale 1.5; sleep 1; }
# The shell as hjem installs it: every file of modules/quickshell, linked,
# plus notification-schema.js from the one generator and the repo's schema.
# Hot reload follows the links only as far as Quickshell watches them;
# restart the session after an edit.
stage="$work/shell"
mkdir -p "$stage"
bash "$shell_dir/stage-runtime.sh" "$shell_dir" "$stage"
bash "$shell_dir/notification-schema-js.sh" \
  "$shell_dir/../../packages/notify-sync/schema/ui-socket.v1.json" > "$stage/notification-schema.js"

theme() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme"; }
theme dark

# Its own session bus too, so the nested shell cannot meet the desktop's
# D-Bus services.
QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
  dbus-run-session -- qs -p "$stage/shell.qml" >"$work/qs.log" 2>&1 &
pids+=($!)
for _ in $(seq 50); do
  qs -p "$stage/shell.qml" ipc show >/dev/null 2>&1 && break
  sleep 0.2
done
if ! qs -p "$stage/shell.qml" ipc show >/dev/null 2>&1; then
  cat "$work/qs.log" >&2
  exit 1
fi
sleep 1

# `capture.sh <outdir> hold` keeps the session up for hand testing. Source
# <outdir>/session.env in another shell, then use qs ipc, socat and grim.
if [ "${2:-}" = hold ]; then
  cat > "$out/session.env" <<EOF
export XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR XDG_STATE_HOME=$XDG_STATE_HOME
export WAYLAND_DISPLAY=$WAYLAND_DISPLAY SWAYSOCK=$SWAYSOCK
export CTL=$work/ctl.sock SHELL_QML=$stage/shell.qml QS_LOG=$work/qs.log HARNESS_LOG=$work/harness.log
EOF
  echo "session up; source $out/session.env"
  wait
fi

ptr() { printf '%s\n' "$*" >&7; sleep 0.2; }
key() { wtype -k "$1"; sleep 0.2; }

# ---- myoko, 1920x1200 logical, dark
centre empty        centre-empty
centre ideal        centre-ideal
centre stress       centre-stress
centre sender-gone  centre-sender-gone
centre local-only   centre-local-only
centre unreachable  centre-unreachable
centre delivery-error centre-delivery-error
ipc hide; ctl "scenario ideal"; ctl "status connecting 0"; sleep 0.3; ipc reveal; shot centre-server-connecting

# Keyboard: the ring and the number keys show only after a key press.
centre ideal        centre-pointer-opened
key Down; key Down; shot centre-keyboard-focus 0.4
# Space opens a long body in place. The open body, the selection and the
# scroll position survive a resize of the screen under the open centre.
ipc hide; ctl "scenario stress"; sleep 0.3; ipc reveal; sleep 0.8
key Down; key Down; key space; shot centre-stress-expanded 0.4
size 1440x1800; shot half-centre-stress-expanded-after-resize 0.4
size 2880x1800
# Stress order: 0 urgent, 1 future clock, 2 long app name, 3 twelve
# actions, 4 every field past its limit.
# An open card cuts nothing: the top of the longest item, then Tab to its
# first action, which scrolls the end of the card (whole image, wrapped
# labels, Show less) into view.
ipc hide; ctl "scenario stress"; sleep 0.3; ipc reveal; sleep 0.8
key Down; key Down; key Down; key Down; key space; shot centre-open-card-top 0.6
key Tab; shot centre-open-card-end 0.6
# Every action by keyboard: twelve Tabs reach the twelfth action of the CI
# item; Enter runs it (see ops.log).
key Up; for _ in $(seq 12); do key Tab; done; shot centre-action-12-focused 0.6
key Return; sleep 0.3
ipc hide
# A popup with cut text offers "Show all in Notifications", which opens the
# centre on that item with its card open.
ctl "scenario empty"; sleep 0.3
ctl "upsert $(python3 -c 'import json; print(json.dumps({"id": 9001, "seq": "rakku-91bd02-9001", "origin": "remote", "host": "rakku", "app_name": "agent-claude", "app_icon": "", "image": None, "summary": "Long report", "body": "Line of a long report that keeps going. " * 12, "actions": [], "urgency": 1, "resident": False, "local_only": False, "created": 1792540000000, "updated": 1792540000000, "sender_alive": True}))')"
shot popup-show-all 0.8
ptr move 1600 139; ptr click; shot popup-show-all-opened-centre 1.2
ipc hide
# Hover, then press without releasing, on "Dismiss all".
ptr move 1819 59; shot centre-hover-dismiss-all 0.3
ptr down; shot centre-pressed-dismiss-all 0.3
ptr move 1000 600; ptr up
ipc hide

popups normal       popup-normal
popups critical     popup-critical
popups image        popup-image
popups remote       popup-remote
popups sender-gone  popup-sender-gone
popups local-only   popup-local-only
popups many         popup-many
# The pointer on a popup pauses its clock; hover on Open.
popups normal       popup-hover 0.3
ptr move 1567 121; sleep 3; shot popup-hover-paused 0.1
ptr move 1000 600
# A normal popup hides after 7 s; the item stays in the centre.
popups normal       popup-after-timeout 8
ipc reveal; shot    popup-after-timeout-centre
ipc hide

# Daemon down: offline text, the retry countdown. Then a daemon that
# accepts the connection but has not sent its snapshot. Then back.
ctl down
shot bar-offline 1.5
ipc reveal; shot centre-offline
# R (or "Try again now") skips the backoff wait.
ctl "snapshot off"; ctl up; key r; shot centre-daemon-connecting 1
ctl down; ctl "snapshot on"; ctl up; ctl "scenario ideal"; sleep 1.5; key r; shot centre-reconnected 1
ipc hide

# ---- light theme
theme light; sleep 0.5
centre ideal        light-centre-ideal
centre unreachable  light-centre-unreachable
centre delivery-error light-centre-delivery-error
popups remote       light-popup-remote 0.3
ctl "popups critical"; shot light-popup-critical
ctl down; ipc reveal; shot light-centre-offline 1.5
ctl up; key r; sleep 1; ipc hide
theme dark; sleep 0.5

# ---- other container shapes: half width, narrow-tall, wide-short
size 1440x1800   # 960x1200, a half-width tile
centre stress       half-centre-stress
popups many         half-popup-many
size 600x1800    # 400x1200, narrow and tall
centre stress       narrow-centre-stress
centre unreachable  narrow-centre-unreachable
centre delivery-error narrow-centre-delivery-error
popups remote       narrow-popup-remote
ctl down; ipc reveal; shot narrow-centre-offline 1.5
ctl up; key r; sleep 1; ipc hide
size 2880x540    # 1920x360, wide and short
centre stress       short-centre-stress
popups many         short-popup-many
size 2880x1800

# ---- the ops, end to end: each must reach the notifyd harness as contract
# section 7 spells it.
centre ideal        ops-before
key Down; key Down; key 1          # action "reply" on the Signal item
key Delete                         # dismiss the item now selected
key Up; key Return                 # Firefox's default action
ipc hide; ctl "scenario empty"; ctl "popups normal"; sleep 1.5
ptr move 1890 53; ptr click        # the popup's dismiss
ctl "scenario ideal"; ipc reveal; sleep 0.8
ptr move 1819 59; ptr click        # Dismiss all
sleep 0.5; ipc hide
grep '^op ' "$work/harness.log" | grep -v subscribe | tee "$out/ops.log"

cp "$work/qs.log" "$out/qs.log"
cp "$work/harness.log" "$out/harness.log"
echo "logs: $out/qs.log $out/harness.log"
