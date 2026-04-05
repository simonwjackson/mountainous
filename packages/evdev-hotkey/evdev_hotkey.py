#!/usr/bin/env python3
"""Generic evdev hotkey daemon.

Watches for an input device by name, listens for a specific key code,
and runs a command on each key press. Automatically reconnects when the
device disappears (e.g. Bluetooth disconnect) and reappears.
"""

import argparse
import logging
import subprocess
import sys
import time

import evdev

LOG = logging.getLogger("evdev-hotkey")


def find_device(name: str) -> evdev.InputDevice | None:
    """Find an input device whose name contains the given substring."""
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if name in dev.name:
            return dev
    return None


def watch(device_name: str, key_code: int, command: list[str], poll_interval: float = 2.0):
    """Main loop: find device, read events, run command on key press."""
    while True:
        dev = find_device(device_name)
        if dev is None:
            LOG.debug("Device %r not found, retrying in %.1fs…", device_name, poll_interval)
            time.sleep(poll_interval)
            continue

        LOG.info("Attached to %s (%s)", dev.name, dev.path)

        try:
            for event in dev.read_loop():
                if event.type == evdev.ecodes.EV_KEY and event.code == key_code and event.value == 1:
                    LOG.info("Key %d pressed — running: %s", key_code, " ".join(command))
                    try:
                        subprocess.Popen(command)
                    except Exception:
                        LOG.exception("Failed to run command")
        except OSError:
            LOG.warning("Device disconnected, will reconnect…")
            time.sleep(poll_interval)


def main():
    parser = argparse.ArgumentParser(description="Generic evdev hotkey daemon")
    parser.add_argument(
        "--device-name",
        required=True,
        help="Substring to match against input device names",
    )
    parser.add_argument(
        "--key-code",
        type=int,
        required=True,
        help="evdev key code to listen for (e.g. 200 for KEY_PLAYCD)",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=2.0,
        help="Seconds between device discovery retries (default: 2)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )
    parser.add_argument(
        "command",
        nargs="+",
        help="Command (and arguments) to run on each key press",
    )

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    LOG.info(
        "Watching for device %r, key code %d → %s",
        args.device_name,
        args.key_code,
        " ".join(args.command),
    )
    watch(args.device_name, args.key_code, args.command, args.poll_interval)


if __name__ == "__main__":
    main()
