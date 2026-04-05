#!/usr/bin/env python3
"""
matrix-notify-daemon: Bridge Matrix rooms to desktop notifications with dismiss sync.

Monitors configured Matrix rooms and creates freedesktop desktop notifications
(via D-Bus) for new messages. Provides bidirectional dismiss sync:

  - Dismissing a notification locally sends a Matrix read receipt
  - Reading on another Matrix client (e.g., SchildiChat) dismisses local notifications

Supports clickable notifications when messages contain a
`dev.mountainous.action_url` custom content field.
"""

import argparse
import asyncio
import logging
import signal
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Set

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from nio import AsyncClient, RoomMessageNotice, RoomMessageText, SyncResponse
from nio.events.ephemeral import ReceiptEvent

log = logging.getLogger("matrix-notify-daemon")

URGENCY_MAP = {"low": 0, "normal": 1, "high": 2, "critical": 2}


@dataclass
class TrackedNotification:
    """A desktop notification we're tracking for dismiss sync."""

    event_id: str
    room_id: str
    notif_id: int
    timestamp: int
    action_url: Optional[str] = None


class NotifyDaemon:
    def __init__(
        self,
        homeserver: str,
        user_id: str,
        access_token: str,
        rooms: list,
    ):
        self.homeserver = homeserver
        self.user_id = user_id
        self.access_token = access_token
        self.watched_rooms: Set[str] = set(rooms)

        # Matrix client
        self.client: Optional[AsyncClient] = None

        # D-Bus notification interface
        self.bus: Optional[MessageBus] = None
        self.notif_iface = None

        # Tracking state for dismiss sync
        self.event_to_notif: Dict[str, TrackedNotification] = {}
        self.notif_to_event: Dict[int, str] = {}
        self.programmatic_closes: Set[int] = set()
        self.own_receipts: Set[tuple] = set()  # (room_id, event_id) pairs we sent

    # ── Main entry point ─────────────────────────────────────────────────

    async def run(self):
        """Connect to Matrix and D-Bus, then sync forever."""
        await self._connect_dbus()
        await self._connect_matrix()
        await self._resolve_and_join_rooms()

        log.info("Initial sync (skipping existing messages)...")
        resp = await self.client.sync(timeout=30000, full_state=True)
        if not isinstance(resp, SyncResponse):
            log.error("Initial sync failed: %s", resp)
            sys.exit(1)
        log.info("Initial sync complete")

        # Register callbacks AFTER initial sync so only new messages trigger
        # notifications. Events from the initial sync are intentionally skipped.
        self.client.add_event_callback(self._on_message, RoomMessageText)
        self.client.add_event_callback(self._on_message, RoomMessageNotice)
        self.client.add_ephemeral_callback(self._on_receipt, ReceiptEvent)

        log.info("Watching rooms: %s", self.watched_rooms)
        await self.client.sync_forever(timeout=30000)

    async def shutdown(self):
        """Clean shutdown of Matrix and D-Bus connections."""
        if self.client:
            await self.client.close()
        if self.bus:
            self.bus.disconnect()
        log.info("Shutdown complete")

    # ── Connection setup ─────────────────────────────────────────────────

    async def _connect_dbus(self):
        """Connect to the session D-Bus and get the notification interface."""
        self.bus = await MessageBus(bus_type=BusType.SESSION).connect()
        introspection = await self.bus.introspect(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
        )
        proxy = self.bus.get_proxy_object(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            introspection,
        )
        self.notif_iface = proxy.get_interface("org.freedesktop.Notifications")
        self.notif_iface.on_notification_closed(self._on_closed)
        self.notif_iface.on_action_invoked(self._on_action)
        log.info("D-Bus notification interface ready")

    async def _connect_matrix(self):
        """Connect to the Matrix homeserver and verify the access token."""
        self.client = AsyncClient(self.homeserver, self.user_id)
        self.client.access_token = self.access_token
        resp = await self.client.whoami()
        if not hasattr(resp, "user_id"):
            log.error("Access token verification failed: %s", resp)
            sys.exit(1)
        log.info("Authenticated as %s", resp.user_id)

    async def _resolve_and_join_rooms(self):
        """Resolve room aliases to IDs and auto-join watched rooms."""
        resolved: Set[str] = set()
        for room in self.watched_rooms:
            if room.startswith("#"):
                resp = await self.client.room_resolve_alias(room)
                if hasattr(resp, "room_id"):
                    resolved.add(resp.room_id)
                    log.info("Resolved %s → %s", room, resp.room_id)
                else:
                    log.error("Cannot resolve room alias %s: %s", room, resp)
                    sys.exit(1)
            else:
                resolved.add(room)
        self.watched_rooms = resolved

        for room_id in self.watched_rooms:
            resp = await self.client.join(room_id)
            if hasattr(resp, "room_id"):
                log.info("Joined %s", room_id)
            else:
                log.warning("Join %s: %s (may already be joined)", room_id, resp)

    # ── Matrix event handlers ────────────────────────────────────────────

    async def _on_message(self, room, event):
        """Handle a new message: create a desktop notification."""
        if room.room_id not in self.watched_rooms:
            return
        if event.sender == self.user_id:
            return

        content = event.source.get("content", {}) if hasattr(event, "source") else {}
        action_url = content.get("dev.mountainous.action_url")
        priority = content.get("dev.mountainous.priority", "normal")
        urgency = URGENCY_MAP.get(priority, 1)

        summary = room.display_name or room.room_id
        body = getattr(event, "body", str(event))

        actions = ["open", "Open"] if action_url else []
        hints = {"urgency": Variant("y", urgency)}

        notif_id = await self.notif_iface.call_notify(
            "matrix-notify-daemon",  # app_name
            0,  # replaces_id (0 = new)
            "mail-unread",  # icon
            summary,
            body,
            actions,
            hints,
            0,  # timeout: 0 = persistent until dismissed
        )

        tracked = TrackedNotification(
            event_id=event.event_id,
            room_id=room.room_id,
            notif_id=notif_id,
            timestamp=event.server_timestamp,
            action_url=action_url,
        )
        self.event_to_notif[event.event_id] = tracked
        self.notif_to_event[notif_id] = event.event_id

        log.info("Notification %d: [%s] %s", notif_id, summary, body[:100])

    async def _on_receipt(self, room, event):
        """
        Handle Matrix read receipts (ephemeral events).

        When we see a read receipt from our own user on a DIFFERENT session
        (e.g., SchildiChat on phone), dismiss all local notifications for
        events up to the receipt target. Matrix read receipts are inherently
        "read up to here" — all earlier events are implicitly read.
        """
        if room.room_id not in self.watched_rooms:
            return

        for receipt in event.receipts:
            if receipt.user_id != self.user_id:
                continue
            if receipt.receipt_type not in ("m.read", "m.read.private"):
                continue

            # Skip receipts WE sent (from this daemon)
            if (room.room_id, receipt.event_id) in self.own_receipts:
                self.own_receipts.discard((room.room_id, receipt.event_id))
                continue

            # Receipt from another session — find the cutoff timestamp.
            # If the target event is tracked, use its timestamp.
            # If not (user read an untracked message), dismiss ALL
            # notifications for this room since the user is clearly
            # reading the room.
            target = self.event_to_notif.get(receipt.event_id)
            cutoff = target.timestamp if target else float("inf")

            to_dismiss = [
                t
                for t in self.event_to_notif.values()
                if t.room_id == room.room_id and t.timestamp <= cutoff
            ]
            for tracked in to_dismiss:
                await self._dismiss_notification(tracked, "remote read receipt")

    # ── D-Bus signal handlers ────────────────────────────────────────────

    def _on_closed(self, notif_id: int, reason: int):
        """
        Handle NotificationClosed D-Bus signal.

        Reasons: 1=expired, 2=dismissed by user, 3=closed programmatically, 4=other
        """
        if notif_id in self.programmatic_closes:
            # We closed this one ourselves (due to remote read receipt)
            self.programmatic_closes.discard(notif_id)
            self._untrack(notif_id)
            return

        if reason == 2:  # Dismissed by user → send read receipt
            event_id = self.notif_to_event.get(notif_id)
            if event_id:
                tracked = self.event_to_notif.get(event_id)
                if tracked:
                    log.info(
                        "User dismissed %d → read receipt for %s",
                        notif_id,
                        event_id,
                    )
                    asyncio.ensure_future(
                        self._send_read_receipt(tracked.room_id, event_id)
                    )
            self._untrack(notif_id)
        elif reason == 1:
            # Expired (timed out). With timeout=0 this shouldn't happen,
            # but if it does, keep tracking so remote dismiss can still work.
            pass
        else:
            self._untrack(notif_id)

    def _on_action(self, notif_id: int, action_key: str):
        """Handle ActionInvoked D-Bus signal (user clicked a notification action)."""
        event_id = self.notif_to_event.get(notif_id)
        if not event_id:
            return
        tracked = self.event_to_notif.get(event_id)
        if not tracked:
            return

        if action_key == "open" and tracked.action_url:
            log.info("Opening: %s", tracked.action_url)
            subprocess.Popen(
                ["xdg-open", tracked.action_url],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        # User interacted → send read receipt
        asyncio.ensure_future(self._send_read_receipt(tracked.room_id, event_id))

    # ── Helpers ──────────────────────────────────────────────────────────

    async def _dismiss_notification(self, tracked: TrackedNotification, reason: str = ""):
        """Programmatically close a desktop notification."""
        log.info("Dismissing %d (%s): %s", tracked.notif_id, tracked.event_id, reason)
        self.programmatic_closes.add(tracked.notif_id)
        try:
            await self.notif_iface.call_close_notification(tracked.notif_id)
        except Exception as e:
            log.warning("Failed to close notification %d: %s", tracked.notif_id, e)
            self.programmatic_closes.discard(tracked.notif_id)
        self._untrack(tracked.notif_id)

    async def _send_read_receipt(self, room_id: str, event_id: str):
        """Send a Matrix read receipt (marks the event as read for our user)."""
        self.own_receipts.add((room_id, event_id))
        try:
            await self.client.room_read_markers(
                room_id,
                fully_read_event=event_id,
                read_event=event_id,
            )
            log.debug("Read receipt sent: %s in %s", event_id, room_id)
        except Exception as e:
            log.warning("Read receipt failed: %s", e)
            self.own_receipts.discard((room_id, event_id))

    def _untrack(self, notif_id: int):
        """Remove a notification from all tracking dicts."""
        event_id = self.notif_to_event.pop(notif_id, None)
        if event_id:
            self.event_to_notif.pop(event_id, None)


def main():
    parser = argparse.ArgumentParser(
        description="Matrix → desktop notification bridge with bidirectional dismiss sync",
    )
    parser.add_argument(
        "--homeserver",
        required=True,
        help="Matrix homeserver URL (e.g., http://matrix.example.ts.net)",
    )
    parser.add_argument(
        "--user-id",
        required=True,
        help="Matrix user ID (e.g., @user:server)",
    )
    parser.add_argument(
        "--access-token-file",
        required=True,
        help="Path to file containing the Matrix access token",
    )
    parser.add_argument(
        "--rooms",
        required=True,
        nargs="+",
        help="Room IDs or aliases to monitor (e.g., !abc:server or #room:server)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    token = Path(args.access_token_file).read_text().strip()
    daemon = NotifyDaemon(args.homeserver, args.user_id, token, args.rooms)

    loop = asyncio.new_event_loop()
    task = None

    def on_signal():
        if task:
            task.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, on_signal)

    try:
        task = loop.create_task(daemon.run())
        loop.run_until_complete(task)
    except (asyncio.CancelledError, KeyboardInterrupt):
        pass
    finally:
        loop.run_until_complete(daemon.shutdown())
        loop.close()


if __name__ == "__main__":
    main()
