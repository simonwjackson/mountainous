#!/usr/bin/env python3
"""A fake notifyd for developing and capturing the Quickshell notification view.

Development only; nothing installs this. It serves the UI socket protocol of
the notify-sync contract, section 7, and nothing else: no D-Bus, no ntfy.

    fake-notifyd.py --socket $XDG_RUNTIME_DIR/notify-sync/ui.sock \
                    --control /tmp/fake-notifyd.ctl --assets /tmp/assets

Send one command per line to the control socket (for example with
`socat - UNIX-CONNECT:/tmp/fake-notifyd.ctl`):

    scenario <name>       replace every item and send a snapshot
    popups <name>         send fresh upserts for that popup set
    status <server> <outbox> [error words…]
    upsert <json item>    one raw upsert, fresh
    down                  drop every client and remove the socket
    up                    listen again
    snapshot on|off       off: accept subscribers but send them nothing

Scenarios and popup sets: Fixtures.SCENARIOS and Fixtures.POPUP_SETS.
`fake-notifyd.py --dump --assets DIR` prints every event it can send.

Each op Quickshell sends is printed on stdout as `op {...}`. Dismiss and
non-resident actions answer with a remove, as notifyd does.
"""

import argparse
import asyncio
import json
import os
import struct
import sys
import time
import zlib

NOW = int(time.time() * 1000)
MIN = 60_000
HOUR = 60 * MIN
DAY = 24 * HOUR


def png(path, width, height, pixel):
    """Write an RGB PNG with no dependencies. pixel(x, y) -> (r, g, b)."""
    rows = b"".join(
        b"\x00" + bytes(c for x in range(width) for c in pixel(x, y)) for y in range(height)
    )

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(data)


def make_assets(directory):
    os.makedirs(directory, exist_ok=True)
    # A dusk ridge line, standing in for a screenshot or an album cover.
    def photo(x, y):
        ridge = 70 + int(18 * ((x * 7) % 23) / 23) - x // 6
        if y > ridge:
            return (30 + y // 8, 38 + y // 10, 44 + y // 12)
        return (200 - y, 120 + y // 2, 90 + y)

    png(os.path.join(directory, "photo.png"), 160, 120, photo)
    # A square app icon given as a path, as some apps do.
    png(os.path.join(directory, "app.png"), 48, 48,
        lambda x, y: (106, 159, 181) if (x - 24) ** 2 + (y - 24) ** 2 < 400 else (20, 20, 20))
    return {
        "photo": os.path.join(directory, "photo.png"),
        "icon": os.path.join(directory, "app.png"),
    }


class Fixtures:
    def __init__(self, assets, host="myoko"):
        self.assets = assets
        self.host = host
        self.next_id = 100

    def item(self, **over):
        self.next_id += 1
        base = {
            "id": self.next_id,
            "seq": f"{self.host}-ae370c-{self.next_id}",
            "origin": "local",
            "host": self.host,
            "app_name": "",
            "app_icon": "",
            "image": None,
            "summary": "",
            "body": "",
            "actions": [],
            "urgency": 1,
            "resident": False,
            "local_only": False,
            "created": NOW - 2 * MIN,
            "updated": NOW - 2 * MIN,
            "sender_alive": True,
        }
        base.update(over)
        if "updated" not in over:
            base["updated"] = base["created"]
        return base

    def remote(self, host, **over):
        over.setdefault("seq", f"{host}-91bd02-{self.next_id + 1}")
        return self.item(origin="remote", host=host, **over)

    # ------------------------------------------------------------ scenarios

    def ideal(self):
        return [
            self.item(app_name="Firefox", app_icon="firefox", summary="Download finished",
                      body="quarterly-storage-report.pdf, 2.4 MB",
                      actions=[{"key": "default", "label": ""}, {"key": "folder", "label": "Show in folder"}],
                      created=NOW - 40_000),
            self.remote("hiyori", app_name="Signal", app_icon="signal-desktop",
                        summary="Ana Ruiz", body="Are you still bringing the tent on Saturday? I can pick it up on the way.",
                        actions=[{"key": "reply", "label": "Reply"}, {"key": "read", "label": "Mark read"}],
                        created=NOW - 6 * MIN),
            self.remote("rakku", app_name="agent-claude", summary="Review ready: notify-sync design",
                        body="Popups, centre and the fake daemon are on the branch. 2 questions in the report.",
                        actions=[{"key": "approve", "label": "Approve"}, {"key": "changes", "label": "Request changes"}],
                        resident=True, created=NOW - 25 * MIN),
            self.item(app_name="Thunderbird", app_icon=self.assets["icon"], summary="3 new messages",
                      body="Tailscale: New device added to your tailnet\nGitHub: [mountainous] CI passed on cairn",
                      image=self.assets["photo"], created=NOW - 2 * HOUR),
            self.item(app_name="nextcloud", summary="Sync complete", body="1,204 files up to date.",
                      urgency=0, created=NOW - 3 * DAY),
        ]

    def critical(self):
        return self.item(app_name="Power", app_icon="battery-caution", urgency=2,
                         summary="Battery at 4%", body="Myoko will suspend in about 3 minutes. Plug in now.",
                         actions=[{"key": "suspend", "label": "Suspend now"}], created=NOW - 10_000)

    def stress(self):
        long_word = "/tundra/permafrost/home/simon/.local/state/notify-sync/" + "x" * 90 + ".db"
        items = [
            self.critical(),
            self.everything_long(),
            self.item(app_name="CI", summary="Build matrix: 12 jobs failed",
                      body="Pick a job to re-run. Only the first nine have number keys.",
                      actions=[{"key": f"rerun-{n}", "label": f"Re-run job {n}"} for n in range(1, 13)],
                      resident=True, created=NOW - 45_000),
            self.item(app_name="An application with an unreasonably long display name that never stops",
                      summary="A summary that runs well past two lines because some apps put the whole message in the summary instead of the body",
                      body=("Paragraph one of a long body. " * 12) + "\n\n" + ("Second paragraph, still going. " * 10),
                      created=NOW - 30_000),
            self.item(app_name="rsync", summary="Path", body="Could not open " + long_word),
            self.item(app_name="", summary="", body="A notification with no app name and no summary."),
            self.item(app_name="Empty", summary="", body=""),
            self.item(app_name="Missing image", summary="The image file is gone", image="/nonexistent/cover.png",
                      app_icon="no-such-icon-anywhere"),
            self.remote("ibuki", app_name="Calendar", summary="Standup in 5 minutes", image=self.assets["photo"],
                        actions=[{"key": k, "label": l} for k, l in [
                            ("join", "Join call"), ("snooze5", "Snooze 5 minutes"), ("snooze15", "Snooze 15 minutes"),
                            ("decline", "Decline with a note to the organiser"), ("map", "Directions"),
                            ("copy", "Copy link"), ("open", "Open event")]]),
            self.item(app_name="Low", summary="Low urgency", urgency=0, created=NOW - 40 * DAY),
            self.item(app_name="Clock skew", summary="From the future", created=NOW + 10 * MIN),
        ]
        for n in range(1, 32):
            items.append(self.item(app_name="Build", summary=f"Job {n} finished", body=f"exit 0 after {n * 7} s",
                                   created=NOW - n * 11 * MIN))
        return items

    def everything_long(self):
        """Every field past any line limit, for the open-card view."""
        host = "build-runner-" + "q" * 70
        return self.remote(
            host,
            seq="build-runner-91bd02-1",
            app_name=("A display name that keeps going " * 9).strip(),
            summary=("A summary longer than six lines once wrapped in a 440 px card, " * 8).strip(),
            body="\n\n".join(f"Paragraph {n} of {60}: " + "the log keeps on going. " * 6 for n in range(1, 61)),
            image=self.assets["photo"],
            actions=[
                {"key": "rerun", "label": "Re-run the failed job on the same runner with debug logging"},
                {"key": "path", "label": "Open_/tundra/permafrost/home/simon/builds/" + "z" * 60},
            ],
            local_only=False,
            created=NOW - 50_000,
        )

    def sender_gone(self):
        return [
            self.item(app_name="Signal", app_icon="signal-desktop", summary="Missed call from Ana Ruiz",
                      actions=[{"key": "call", "label": "Call back"}, {"key": "msg", "label": "Message"}],
                      sender_alive=False, created=NOW - 50 * MIN),
            self.remote("hiyori", app_name="Steam", summary="Download paused",
                        actions=[{"key": "resume", "label": "Resume"}], sender_alive=False),
            self.item(app_name="Firefox", app_icon="firefox", summary="Download finished", body="tent-manual.pdf",
                      actions=[{"key": "default", "label": ""}, {"key": "folder", "label": "Show in folder"}]),
        ]

    def local_only(self):
        return [
            self.item(app_name="OBS", summary="Recording started", body="Scene: Desk camera",
                      local_only=True, actions=[{"key": "stop", "label": "Stop"}], created=NOW - 20_000),
            self.item(app_name="Firefox", app_icon="firefox", summary="Download finished", body="tent-manual.pdf"),
            self.item(app_name="1Password", summary="Copied password", body="Clears from the clipboard in 90 s",
                      local_only=True, urgency=0),
        ]

    # Every scenario and popup set, for the capture script and --dump.
    SCENARIOS = ["empty", "ideal", "stress", "sender-gone", "local-only", "unreachable"]
    POPUP_SETS = ["normal", "critical", "image", "remote", "sender-gone", "local-only", "many"]

    def scenario(self, name):
        if name == "empty":
            return [], status("connected")
        if name == "ideal":
            return [self.critical()] + self.ideal(), status("connected")
        if name == "stress":
            return self.stress(), status("connected")
        if name == "sender-gone":
            return self.sender_gone(), status("connected")
        if name == "local-only":
            return self.local_only(), status("connected")
        if name == "unreachable":
            return self.ideal()[:3], status("unreachable", 7, "dial tcp 100.101.7.12:443: connect: connection refused")
        raise ValueError(name)

    def popups(self, name):
        if name == "normal":
            return self.ideal()[:1]
        if name == "critical":
            return [self.critical()]
        if name == "image":
            return [self.ideal()[3]]
        if name == "remote":
            return [self.ideal()[1], self.ideal()[2]]
        if name == "sender-gone":
            return self.sender_gone()[:1]
        if name == "local-only":
            return self.local_only()[:1]
        if name == "many":
            return [self.item(app_name="Build", summary=f"Job {n} finished", body=f"exit 0 after {n * 7} s")
                    for n in range(1, 7)]
        raise ValueError(name)


def status(server, outbox=0, error=None):
    return {"server": server, "outbox": outbox, "last_error": error}


class Daemon:
    def __init__(self, socket_path, fixtures):
        self.socket_path = socket_path
        self.fixtures = fixtures
        self.items = {}
        self.status = status("connected")
        self.clients = set()       # subscribed: they get events
        self.connections = set()   # every open connection
        self.server = None
        self.send_snapshot = True
        # --dump collects every event line here instead of sending it.
        self.sink = None

    def snapshot(self):
        return {"type": "snapshot", "items": list(self.items.values()), "status": self.status}

    async def broadcast(self, event):
        if self.sink is not None:
            self.sink.append(json.dumps(event))
        line = (json.dumps(event) + "\n").encode()
        for writer in list(self.clients):
            try:
                writer.write(line)
                await writer.drain()
            except (ConnectionError, RuntimeError):
                self.clients.discard(writer)

    async def handle(self, reader, writer):
        subscribed = False
        self.connections.add(writer)
        try:
            while True:
                raw = await reader.readline()
                if not raw:
                    break
                try:
                    op = json.loads(raw)
                except json.JSONDecodeError:
                    print("bad line", raw, flush=True)
                    continue
                print("op", json.dumps(op), flush=True)
                kind = op.get("op")
                if kind == "subscribe" and not subscribed and self.send_snapshot:
                    subscribed = True
                    self.clients.add(writer)
                    writer.write((json.dumps(self.snapshot()) + "\n").encode())
                    await writer.drain()
                elif kind == "dismiss":
                    await self.remove(op.get("id"), 2)
                elif kind == "dismiss_all":
                    for item_id in list(self.items):
                        await self.remove(item_id, 2)
                elif kind == "action":
                    item = self.items.get(op.get("id"))
                    if item and not item["resident"]:
                        await self.remove(item["id"], 2)
        finally:
            self.clients.discard(writer)
            self.connections.discard(writer)
            writer.close()

    async def remove(self, item_id, reason):
        if self.items.pop(item_id, None) is not None:
            await self.broadcast({"type": "remove", "id": item_id, "reason": reason})

    async def up(self):
        if self.server:
            return
        os.makedirs(os.path.dirname(self.socket_path), exist_ok=True)
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)
        self.server = await asyncio.start_unix_server(self.handle, path=self.socket_path)

    async def down(self):
        if self.server:
            self.server.close()
            self.server = None
        for writer in list(self.connections):
            writer.close()
        self.clients.clear()
        self.connections.clear()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

    async def command(self, text):
        words = text.split()
        if not words:
            return "ok"
        verb = words[0]
        if verb == "scenario":
            items, self.status = self.fixtures.scenario(words[1])
            self.items = {i["id"]: i for i in items}
            await self.broadcast(self.snapshot())
        elif verb == "popups":
            for item in self.fixtures.popups(words[1]):
                # A popup is news: it arrives now.
                item["created"] = item["updated"] = int(time.time() * 1000)
                self.items[item["id"]] = item
                await self.broadcast({"type": "upsert", "item": item, "fresh": True})
        elif verb == "status":
            self.status = status(words[1], int(words[2]), " ".join(words[3:]) or None)
            await self.broadcast({"type": "status", "status": self.status})
        elif verb == "upsert":
            item = json.loads(text.split(None, 1)[1])
            self.items[item["id"]] = item
            await self.broadcast({"type": "upsert", "item": item, "fresh": True})
        elif verb == "snapshot":
            self.send_snapshot = words[1] == "on"
        elif verb == "down":
            await self.down()
        elif verb == "up":
            await self.up()
        else:
            return "unknown " + verb
        return "ok"


async def dump(assets):
    """Print, one per line, every event this daemon can send: each scenario's
    snapshot, each popup set's upserts, each status, and the removes that
    dismiss and dismiss_all answer with. checks.notification-view validates
    this output against the socket schema."""
    daemon = Daemon("", Fixtures(make_assets(assets)))
    daemon.sink = []
    for name in Fixtures.SCENARIOS:
        await daemon.command("scenario " + name)
    for name in Fixtures.POPUP_SETS:
        await daemon.command("popups " + name)
    await daemon.command("status connecting 0")
    await daemon.command("status unreachable 7 dial tcp: connect: connection refused")
    await daemon.command("status connected 0")
    first = next(iter(daemon.items))
    await daemon.remove(first, 2)
    for item_id in list(daemon.items):
        await daemon.remove(item_id, 2)
    print("\n".join(daemon.sink))


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket")
    parser.add_argument("--control")
    parser.add_argument("--assets", required=True)
    parser.add_argument("--scenario", default="ideal")
    parser.add_argument("--dump", action="store_true", help="print every event and exit")
    args = parser.parse_args()
    if args.dump:
        await dump(args.assets)
        return
    if not args.socket or not args.control:
        parser.error("--socket and --control are required unless --dump")

    daemon = Daemon(args.socket, Fixtures(make_assets(args.assets)))
    await daemon.command("scenario " + args.scenario)
    await daemon.up()

    async def control(reader, writer):
        while True:
            raw = await reader.readline()
            if not raw:
                break
            try:
                reply = await daemon.command(raw.decode().strip())
            except Exception as error:  # report, keep serving
                reply = f"error {error!r}"
            writer.write((reply + "\n").encode())
            await writer.drain()
        writer.close()

    if os.path.exists(args.control):
        os.unlink(args.control)
    ctl = await asyncio.start_unix_server(control, path=args.control)
    print("fake notifyd ready", args.socket, flush=True)
    async with ctl:
        await ctl.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
