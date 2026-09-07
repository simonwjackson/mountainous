#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Guest-only real socket endpoints with a line-oriented test control channel."""

import argparse
import json
import os
from pathlib import Path
import socket
import sys
import threading
import time


def channel(handler):
    for line in sys.stdin:
        try:
            result = handler(json.loads(line))
        except (OSError, TimeoutError) as error:
            result = {"kind": "blocked", "error": type(error).__name__}
        print(json.dumps(result), flush=True)


def probe():
    sockets = {}

    def handle(request):
        key = request["key"]
        if request["operation"] == "open":
            family = socket.AF_INET6 if request["family"] == 6 else socket.AF_INET
            kind = (
                socket.SOCK_STREAM
                if request["protocol"] == "tcp"
                else socket.SOCK_DGRAM
            )
            sock = socket.socket(family, kind)
            sockets[key] = sock
            sock.settimeout(0.35)
            if "source" in request:
                # Share a fixture listener's source port to exercise unsolicited
                # outbound TCP as well as ordinary server replies.
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                sock.bind(
                    (
                        "::" if family == socket.AF_INET6 else "0.0.0.0",
                        request["source"],
                    )
                )
            sock.connect((request["host"], request["port"]))
        else:
            sock = sockets[key]
        operation = request["operation"]
        if operation == "close":
            sock.close()
            return {"kind": "ok"}
        if operation != "receive":
            sock.sendall(request["value"].encode() + b"\n")
        value = sock.recv(4096)
        if not value:
            return {"kind": "closed"}
        return {"kind": "ok", "value": value.decode().strip()}

    channel(handle)


def serve(ports, log):
    peers = []
    mutex = threading.Lock()
    log_lock = threading.Lock()
    listeners = []

    def record(value):
        with log_lock, log.open("a") as output:
            output.write(value.decode())
            output.flush()

    def tcp_connection(connection):
        with mutex:
            peers.append((connection, None))
        try:
            with connection.makefile("rb") as reader:
                for value in reader:
                    record(value)
                    connection.sendall(value)
        except OSError:
            pass
        finally:
            with mutex:
                peers.remove((connection, None))
            connection.close()

    def tcp_listener(listener):
        while True:
            connection, _ = listener.accept()
            threading.Thread(
                target=tcp_connection, args=(connection,), daemon=True
            ).start()

    def udp_listener(listener):
        while True:
            value, address = listener.recvfrom(4096)
            with mutex:
                peer = (listener, address)
                if peer not in peers:
                    peers.append(peer)
            record(value)
            listener.sendto(value, address)

    for family in (socket.AF_INET, socket.AF_INET6):
        for protocol, numbers in ports.items():
            for port in numbers:
                kind = socket.SOCK_STREAM if protocol == "tcp" else socket.SOCK_DGRAM
                listener = socket.socket(family, kind)
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                if family == socket.AF_INET6:
                    listener.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                listener.bind(("::" if family == socket.AF_INET6 else "0.0.0.0", port))
                if protocol == "tcp":
                    listener.listen(128)
                listeners.append(listener)
                target = tcp_listener if protocol == "tcp" else udp_listener
                threading.Thread(target=target, args=(listener,), daemon=True).start()

    def handle(request):
        if request["operation"] == "broadcast":
            with mutex:
                for connection, address in peers:
                    if connection.getsockname()[1] not in request["ports"]:
                        continue
                    try:
                        value = request["value"].encode() + b"\n"
                        if address is None:
                            connection.sendall(value)
                        else:
                            connection.sendto(value, address)
                    except OSError:
                        pass
        return {"kind": "ok", "listeners": len(listeners), "pid": os.getpid()}

    channel(handle)


def spray(targets, send_buffer=None):
    """Keep established TCP and connected UDP sending during firewall operations."""
    sockets = []
    for family, host in targets:
        for kind, port in ((socket.SOCK_STREAM, 39217), (socket.SOCK_DGRAM, 60500)):
            sock = socket.socket(
                socket.AF_INET6 if family == 6 else socket.AF_INET, kind
            )
            if send_buffer is not None:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, send_buffer)
                assert (
                    sock.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
                    >= 2 * send_buffer
                ), "guest send-buffer limit clipped requested capacity"
            sock.settimeout(2)
            sock.connect((host, port))
            sock.sendall(b"spray-baseline\n")
            assert sock.recv(4096) == b"spray-baseline\n"
            sock.setblocking(False)
            sockets.append(sock)
    condition = threading.Condition()
    enabled = False
    state = "starting"
    failure = None
    payload = b"firewall-leak-check\n"
    offsets = [0 for _ in sockets]
    progress = [dict(attempts=0, sends=0, sent_bytes=0, blocked=0) for _ in sockets]

    def send():
        nonlocal state, failure
        try:
            while True:
                with condition:
                    while not enabled:
                        state = "paused"
                        condition.notify_all()
                        condition.wait()
                    for index, sock in enumerate(sockets):
                        counts = progress[index]
                        counts["attempts"] += 1
                        try:
                            sent = sock.send(payload[offsets[index] :])
                        except BlockingIOError:
                            counts["blocked"] += 1
                            continue
                        if sent == 0:
                            raise BrokenPipeError("sender made no progress")
                        counts["sends"] += 1
                        counts["sent_bytes"] += sent
                        # Preserve complete stream payloads even after partial
                        # nonblocking writes, so receive-log checks stay valid.
                        offsets[index] = (offsets[index] + sent) % len(payload)
                    state = "active"
                    condition.notify_all()
                time.sleep(0.001)
        except Exception as error:
            with condition:
                failure = type(error).__name__
                state = "failed"
                condition.notify_all()

    worker = threading.Thread(target=send, daemon=True)
    worker.start()

    def handle(request):
        nonlocal enabled
        with condition:
            operation = request["operation"]
            if operation == "start":
                enabled = True
            elif operation == "stop":
                enabled = False
            elif operation not in ("ready", "status"):
                return {"kind": "failed", "error": "UnknownOperation"}
            expected = "active" if enabled else "paused"
            before = [item["sent_bytes"] for item in progress]

            def acknowledged():
                return (
                    failure is not None
                    or not worker.is_alive()
                    or (
                        state == expected
                        and (
                            not enabled
                            or all(
                                item["sent_bytes"] > earlier
                                for item, earlier in zip(progress, before)
                            )
                        )
                    )
                )

            condition.notify_all()
            acknowledged_in_time = condition.wait_for(acknowledged, timeout=5)
            if failure is not None:
                return {"kind": "failed", "error": failure}
            if not worker.is_alive():
                return {"kind": "failed", "error": "WorkerExited"}
            if not acknowledged_in_time:
                return {"kind": "failed", "error": "WorkerHandshakeTimeout"}
            return {
                "kind": "ok",
                "state": state,
                "progress": [item.copy() for item in progress],
            }

    channel(handle)
    if failure is not None:
        raise SystemExit(1)


def main():
    if not Path("/etc/federation-network-vm-fixture").is_file():
        raise SystemExit("isolated network fixture only")
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("probe", "serve", "spray", "ssh-echo"))
    parser.add_argument("--ports", type=json.loads)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--targets", type=json.loads)
    parser.add_argument("--send-buffer", type=int)
    args = parser.parse_args()
    if args.mode == "probe":
        probe()
    elif args.mode == "serve":
        serve(args.ports, args.log)
    elif args.mode == "spray":
        spray(args.targets, args.send_buffer)
    else:
        for line in sys.stdin:
            print(line.strip(), flush=True)


if __name__ == "__main__":
    main()
