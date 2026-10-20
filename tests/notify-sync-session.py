"""VM user-session proof. This is not the throwaway spike."""
import asyncio
import json
import os
import subprocess
import time
import urllib.request

from dbus_fast import Message, MessageType, Variant
from dbus_fast.aio import MessageBus

BASE = "http://127.0.0.1:2586"
IFACE = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"


def events():
    with urllib.request.urlopen(BASE + "/notify/json?poll=1&since=all") as response:
        return [json.loads(line) for line in response if line.strip()]


def request(method, path, data=None):
    req = urllib.request.Request(BASE + path, data=data, method=method)
    with urllib.request.urlopen(req) as response:
        return response.read()


def control(seq, kind, key=""):
    request("POST", "/notify-ctl", json.dumps({"v": 1, "type": kind, "seq": seq, "key": key}).encode())


async def main():
    bus = await MessageBus().connect()
    signals = []

    def on_message(msg):
        if msg.message_type == MessageType.SIGNAL and msg.interface == IFACE:
            signals.append((msg.member, list(msg.body)))

    bus.add_message_handler(on_message)
    await bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                           interface="org.freedesktop.DBus", member="AddMatch", signature="s",
                           body=["type='signal',sender='org.freedesktop.Notifications',interface='" + IFACE + "'"]))

    async def until(predicate, label):
        end = time.monotonic() + 15
        while time.monotonic() < end:
            if predicate():
                return
            await asyncio.sleep(0.05)
        raise AssertionError(label)

    async def notify(summary, replaces=0, transient=False):
        result = await bus.call(Message(destination=IFACE, path=PATH, interface=IFACE, member="Notify",
                                        signature="susssasa{sv}i", body=["vm-app", replaces, "", summary, "body",
                                        ["go", "Go"], {"transient": Variant("b", transient)}, 300]))
        assert result.message_type != MessageType.ERROR, result.body
        return result.body[0]

    async def sequence(summary):
        await until(lambda: any(e.get("title") == summary for e in events()), "publish " + summary)
        return next(e["sequence_id"] for e in events() if e.get("title") == summary)

    proc = await asyncio.create_subprocess_exec("notify-send", "-p", "-w", "VM wait", stdout=asyncio.subprocess.PIPE)
    nid = int(await proc.stdout.readline())
    seq = await sequence("VM wait")
    subprocess.run(["notify", "clear", seq], check=True)
    await asyncio.wait_for(proc.wait(), 15)
    assert proc.returncode == 0
    await until(lambda: ("NotificationClosed", [nid, 2]) in signals, "exact close reason 2")
    print("PASS notify-send -w + CLI clear + reason 2", flush=True)

    proc = await asyncio.create_subprocess_exec("notify-send", "-p", "-A", "go=Go", "VM action", stdout=asyncio.subprocess.PIPE)
    nid = int(await proc.stdout.readline())
    seq = await sequence("VM action")
    control(seq, "action", "go")
    assert (await asyncio.wait_for(proc.stdout.readline(), 15)).strip() == b"go"
    await asyncio.wait_for(proc.wait(), 15)
    await until(lambda: ("ActionInvoked", [nid, "go"]) in signals, "action signal")
    print("PASS notify-send -A + phone action round trip", flush=True)

    nid = await notify("VM replace 1")
    seq = await sequence("VM replace 1")
    assert await notify("VM replace 2", nid) == nid
    assert await sequence("VM replace 2") == seq
    assert len({e["sequence_id"] for e in events() if e.get("title", "").startswith("VM replace")}) == 1
    await asyncio.sleep(0.5)
    assert not any(name == "NotificationClosed" and args[0] == nid for name, args in signals)
    print("PASS replaces_id one seq; popup timeout leaves store open", flush=True)

    await notify("VM transient", transient=True)
    await asyncio.sleep(0.6)
    assert not any(e.get("title") == "VM transient" for e in events())
    print("PASS transient never reaches server", flush=True)

    nid = await notify("VM restart")
    seq = await sequence("VM restart")
    subprocess.run(["systemctl", "--user", "stop", "notifyd"], check=True)
    subprocess.run(["notify", "clear", seq], check=True)
    subprocess.run(["systemctl", "--user", "start", "notifyd"], check=True)
    await until(lambda: ("NotificationClosed", [nid, 2]) in signals, "restart catch-up reason 2")
    print("PASS restart catch-up", flush=True)

    nid = await notify("VM Done")
    seq = await sequence("VM Done")
    latest = next(e for e in reversed(events()) if e.get("sequence_id") == seq and e["event"] == "message")
    done = next(a for a in latest["actions"] if a["label"] == "Done")
    assert done["method"] == "POST" and done["url"].endswith("/notify-ctl")
    req = urllib.request.Request(done["url"], data=done["body"].encode(), method=done["method"])
    with urllib.request.urlopen(req):
        pass
    await until(lambda: ("NotificationClosed", [nid, 2]) in signals, "hub Done reason 2")
    print("PASS Done button through hub", flush=True)
    bus.disconnect()


asyncio.run(main())
