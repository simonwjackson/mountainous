#!/usr/bin/env python3
"""Adapt the pinned hypr-session-restore script for Myoko.

Two jobs, both applied to the script path given as the first argument:

1. Small token rewrites: Myoko's Hyprland instance, its web-app and Chromium
   launchers, the Ghostty working-directory option, snapshot permissions, and
   a launch-once rule per (pid, class).
2. Replace upstream's best-effort sweep with deterministic placement. Upstream
   launches every saved window and then moves whatever it happens to see.
   Single-instance apps (Zed, Chromium) ignore the per-launch workspace rule,
   so the sweep cannot place their extra windows and its 20 second deadline
   ends before slow apps appear. The replacement waits for the saved windows,
   matches them to live clients by class and title, and moves each client to
   its saved workspace position.

The patch fails loudly when an anchor is missing, so a pinned-version bump
cannot silently drop a rewrite.
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    source = stream.read()


def sub(old, new):
    global source
    if old not in source:
        raise SystemExit(f"patch anchor not found: {old[:70]!r}")
    source = source.replace(old, new, 1)


# --- 1. token rewrites -------------------------------------------------------

sub('["hyprctl", "-j", cmd]', '["hyprctl", "--instance", "0", "-j", cmd]')
sub('["hyprctl", "dispatch", lua]', '["hyprctl", "--instance", "0", "dispatch", lua]')
sub("import time", "import time\nfrom urllib.parse import urlsplit")
sub("def save():", "def save():\n    os.umask(0o077)")
sub(
    "    os.makedirs(STATE_DIR, exist_ok=True)",
    "    if not windows:\n"
    "        return 0\n"
    "    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)\n"
    "    os.chmod(STATE_DIR, 0o700)",
)
sub(
    '    "Alacritty": ("alacritty", "--working-directory", "-e"),',
    '    "Alacritty": ("alacritty", "--working-directory", "-e"),\n'
    '    "com.mitchellh.ghostty": ("ghostty", "--working-directory=", "-e"),',
)
sub(
    "            cmd = [binary, cwd_flag, cwd]",
    '            cmd = [binary, cwd_flag + cwd] if cwd_flag.endswith("=") else [binary, cwd_flag, cwd]',
)
sub(
    "        return shlex.join([binary, cwd_flag, cwd])",
    '        cmd = [binary, cwd_flag + cwd] if cwd_flag.endswith("=") else [binary, cwd_flag, cwd]\n'
    "        return shlex.join(cmd)",
)
sub(
    '            # one relaunch per process; extra windows of the same pid are',
    "            # launch each class once per pid; a Chromium app can share",
)
sub(
    "            # placed by the sweep pass (single-instance apps reopen them)",
    "            # a pid with a browser window and still needs its own launch",
)
sub(
    '            "spawn": pid not in spawned_pids,',
    '            "spawn": (pid, c["class"]) not in spawned_pids,',
)
sub(
    "        spawned_pids.add(pid)",
    '        spawned_pids.add((pid, c["class"]))',
)
sub(
    "    return shlex.join(argv)",
    '    if len(argv) == 1 and " " in argv[0]:\n'
    "        argv = shlex.split(argv[0])\n"
    "    for arg in argv:\n"
    '        if cls.startswith("chrome-") and arg.startswith("--app="):\n'
    '            app_url = arg.removeprefix("--app=")\n'
    "            parsed = urlsplit(app_url)\n"
    '            if parsed.scheme in ("https", "http") and parsed.hostname and cls == f"chrome-{parsed.hostname}__-Default":\n'
    '                return shlex.join(["/run/current-system/sw/bin/web-app", app_url])\n'
    '    if cls == "chromium-browser" and "chromium-unwrapped-" in argv[0] and argv[0].endswith("/libexec/chromium/chromium"):\n'
    '        argv[0] = "/run/current-system/sw/bin/chromium"\n'
    "    return shlex.join(argv)",
)

# --- 2. deterministic placement ---------------------------------------------

PLACEMENT = '''RESTORE_MATCH_TIMEOUT = 45
RESTORE_SETTLE_SECONDS = 3
RESTORE_PLACE_ROUNDS = 5
RESTORE_PLACE_SETTLE = 1.5


def _target_key(win):
    ws = win.get("workspace") or {}
    at = win.get("at") or [0, 0]
    return (ws.get("id", 0), bool(win.get("floating")), at[0], at[1])


def _target_ranks(windows):
    """Map each saved normal workspace id to its 1-based position on the strip.

    The Lua strip renumbers occupied workspaces to 1..N, so the saved numeric
    id is not stable across a restart. The position is.
    """
    ids = sorted({
        (w.get("workspace") or {}).get("id", 0)
        for w in windows
        if (w.get("workspace") or {}).get("id", 0) > 0
    })
    return {ws_id: index + 1 for index, ws_id in enumerate(ids)}


def _target_workspace(win, ranks):
    ws = win.get("workspace") or {}
    name = ws.get("name", "")
    wid = ws.get("id", 0)
    if name.startswith("special"):
        return name
    if wid > 0:
        return str(ranks.get(wid, wid))
    return name or str(wid)


def _new_clients(candidates, baseline):
    return {a: c for a, c in candidates.items() if a not in baseline}


def match_windows(windows, candidates):
    """Match saved windows to live clients. Pure.

    Exact class and title first, then class alone in saved order. Each client
    is used once. Returns (pairs, missing, unmatched).
    """
    remaining = dict(candidates)
    pairs = []
    taken = set()
    for index, win in enumerate(windows):
        for address, client in list(remaining.items()):
            if client.get("class") == win.get("class") and client.get("title") == win.get("title"):
                pairs.append((index, address))
                taken.add(index)
                del remaining[address]
                break
    missing = []
    for index, win in enumerate(windows):
        if index in taken:
            continue
        for address, client in list(remaining.items()):
            if client.get("class") == win.get("class"):
                pairs.append((index, address))
                taken.add(index)
                del remaining[address]
                break
        else:
            missing.append(index)
    return pairs, missing, sorted(remaining)


def placement_actions(windows, pairs, ranks):
    """Return the Lua dispatches that put each matched window in place. Pure."""
    actions = []
    for index, address in sorted(pairs, key=lambda pair: _target_key(windows[pair[0]])):
        win = windows[index]
        target = _target_workspace(win, ranks)
        window = lua_str("address:" + address)
        actions.append(
            f"hl.dsp.window.move({{ workspace = {lua_str(target)}, follow = false, window = {window} }})"
        )
        if win.get("floating"):
            at = win.get("at") or [0, 0]
            size = win.get("size") or [0, 0]
            actions.append(f"hl.dsp.window.float({{ action = 'on', window = {window} }})")
            actions.append(f"hl.dsp.window.move({{ x = {at[0]}, y = {at[1]}, window = {window} }})")
            actions.append(f"hl.dsp.window.resize({{ x = {size[0]}, y = {size[1]}, window = {window} }})")
        if win.get("pinned"):
            actions.append(f"hl.dsp.window.pin({{ action = 'on', window = {window} }})")
        fs = win.get("fullscreen", 0)
        if fs:
            mode = "fullscreen" if fs & 2 else "maximized"
            actions.append(
                f"hl.dsp.window.fullscreen({{ mode = '{mode}', action = 'set', window = {window} }})"
            )
    return actions


def _settled(windows, pairs, ranks):
    live = current_clients()
    for index, address in pairs:
        client = live.get(address)
        if client is None:
            return False
        want = _target_workspace(windows[index], ranks)
        workspace = client.get("workspace") or {}
        if want.startswith("special"):
            if workspace.get("name", "") != want:
                return False
        elif str(workspace.get("id")) != want:
            return False
    return True


def _wait_until_stable(baseline, deadline):
    """Wait until the new-window count stops growing, or the deadline passes."""
    last = -1
    quiet = 0
    while time.time() < deadline:
        time.sleep(1)
        count = len(_new_clients(current_clients(), baseline))
        if count == last:
            quiet += 1
            if quiet >= RESTORE_SETTLE_SECONDS:
                return
        else:
            last = count
            quiet = 0


def restore():
    if os.path.exists(DISABLE_FLAG):
        return
    try:
        with open(SESSION_FILE) as f:
            session = json.load(f)
    except (OSError, ValueError):
        return
    windows = [w for w in session.get("windows", []) if w.get("class") not in EXCLUDE_CLASSES]
    if not windows:
        return

    initial = current_clients()
    if len(initial) > 3:
        print("hypr-session-restore: session already populated, aborting", file=sys.stderr)
        return
    baseline = set(initial)

    ranks = _target_ranks(windows)
    order = sorted(range(len(windows)), key=lambda index: _target_key(windows[index]))
    for index in order:
        win = windows[index]
        if win.get("spawn"):
            dispatch(f"hl.dsp.exec_cmd({lua_long_str(win['cmd'])}, {exec_rules(win)})")
            time.sleep(SPAWN_STAGGER)

    # Slow single-instance apps (Zed) open their extra windows well after the
    # launch. Re-match and re-place until every saved window is present, so a
    # window that appears after the first placement still reaches its page.
    deadline = time.time() + RESTORE_MATCH_TIMEOUT
    missing = []
    while True:
        _wait_until_stable(baseline, deadline)
        pairs, missing, _unmatched = match_windows(
            windows, _new_clients(current_clients(), baseline)
        )
        for _round in range(RESTORE_PLACE_ROUNDS):
            for action in placement_actions(windows, pairs, ranks):
                dispatch(action)
            time.sleep(RESTORE_PLACE_SETTLE)
            if _settled(windows, pairs, ranks):
                break
        if not missing or time.time() >= deadline:
            break

    if missing:
        classes = sorted({windows[index].get("class", "") for index in missing})
        print(
            "hypr-session-restore: %d saved window(s) did not reappear: %s"
            % (len(missing), ", ".join(classes)),
            file=sys.stderr,
        )


'''

start = source.index("def restore():")
end = source.index("def daemon():")
source = source[:start] + PLACEMENT + source[end:]

with open(path, "w", encoding="utf-8") as stream:
    stream.write(source)

print("patched hypr-session-restore for Myoko")
