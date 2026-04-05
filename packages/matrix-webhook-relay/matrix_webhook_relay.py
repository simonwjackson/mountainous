#!/usr/bin/env python3
"""
matrix-webhook-relay: HTTP webhook → Matrix room relay.

Accepts POST /hook with JSON payloads and forwards them as messages to a
configured Matrix room. Designed to sit on localhost and receive webhooks
from services like Sonarr, Radarr, and systemd failure handlers.

Payload schema:
    {
        "title": "Sonarr",                        # required
        "body": "Episode downloaded: ...",         # required
        "priority": "normal",                      # optional: low|normal|high|critical
        "url": "https://tv.example.ts.net"         # optional: action URL for desktop click
    }

The relay posts to Matrix as an m.room.message event with custom fields:
    - dev.mountainous.action_url  (if url is present)
    - dev.mountainous.priority    (if priority is present)
"""

import argparse
import asyncio
import json
import logging
import signal
import sys
from pathlib import Path

from aiohttp import web

log = logging.getLogger("matrix-webhook-relay")

VALID_PRIORITIES = {"low", "normal", "high", "critical"}


class WebhookRelay:
    def __init__(self, homeserver: str, room_id: str, token_file: str, port: int, bind: str):
        self.homeserver = homeserver.rstrip("/")
        self.room_id = room_id
        self.token_file = token_file
        self.port = port
        self.bind = bind
        self._access_token = None
        self._session = None
        self._resolved_room_id = None

    def _read_token(self) -> str:
        """Read the bot access token from disk (re-read each time for token rotation)."""
        return Path(self.token_file).read_text().strip()

    async def _matrix_request(self, method: str, path: str, json_body=None):
        """Make an authenticated request to the Matrix homeserver."""
        import aiohttp

        if self._session is None:
            self._session = aiohttp.ClientSession()

        token = self._read_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        url = f"{self.homeserver}{path}"
        async with self._session.request(method, url, headers=headers, json=json_body) as resp:
            body = await resp.json()
            if resp.status >= 400:
                log.error("Matrix API %s %s → %d: %s", method, path, resp.status, body)
            return resp.status, body

    async def _resolve_room(self) -> str:
        """Resolve room alias to room ID, or return room ID as-is."""
        if self._resolved_room_id:
            return self._resolved_room_id

        if self.room_id.startswith("!"):
            self._resolved_room_id = self.room_id
        elif self.room_id.startswith("#"):
            from urllib.parse import quote

            encoded = quote(self.room_id, safe="")
            status, body = await self._matrix_request(
                "GET", f"/_matrix/client/v3/directory/room/{encoded}"
            )
            if status == 200:
                self._resolved_room_id = body["room_id"]
                log.info("Resolved %s → %s", self.room_id, self._resolved_room_id)
            else:
                raise RuntimeError(f"Cannot resolve room {self.room_id}: {body}")
        else:
            raise ValueError(f"Invalid room identifier: {self.room_id}")

        return self._resolved_room_id

    async def _send_message(self, title: str, body: str, priority: str = "normal", url: str = None):
        """Send a message to the notification room."""
        room_id = await self._resolve_room()

        from urllib.parse import quote

        encoded_room = quote(room_id, safe="")
        txn_id = f"{id(self)}_{asyncio.get_event_loop().time()}"

        # Build message content with custom fields for the desktop daemon
        content = {
            "msgtype": "m.text",
            "body": f"{title}: {body}" if title else body,
            "format": "org.matrix.custom.html",
            "formatted_body": f"<b>{title}</b><br/>{body}" if title else body,
            "dev.mountainous.priority": priority,
        }
        if url:
            content["dev.mountainous.action_url"] = url

        status, resp_body = await self._matrix_request(
            "PUT",
            f"/_matrix/client/v3/rooms/{encoded_room}/send/m.room.message/{txn_id}",
            json_body=content,
        )

        if status == 200:
            event_id = resp_body.get("event_id", "unknown")
            log.info("Sent to %s: [%s] %s (event: %s)", room_id, title, body[:80], event_id)
            return event_id
        else:
            raise RuntimeError(f"Failed to send message: {status} {resp_body}")

    # ── HTTP handlers ────────────────────────────────────────────────────

    async def handle_hook(self, request: web.Request) -> web.Response:
        """POST /hook — receive a webhook and relay to Matrix."""
        try:
            payload = await request.json()
        except json.JSONDecodeError:
            return web.json_response({"error": "invalid JSON"}, status=400)

        title = payload.get("title")
        body = payload.get("body")

        if not title or not body:
            return web.json_response(
                {"error": "missing required fields: title, body"}, status=400
            )

        priority = payload.get("priority", "normal")
        if priority not in VALID_PRIORITIES:
            return web.json_response(
                {"error": f"invalid priority: {priority}, must be one of {VALID_PRIORITIES}"},
                status=400,
            )

        url = payload.get("url")

        try:
            event_id = await self._send_message(title, body, priority, url)
            return web.json_response({"event_id": event_id})
        except Exception as e:
            log.exception("Failed to relay webhook")
            return web.json_response({"error": str(e)}, status=502)

    async def handle_arr(self, request: web.Request) -> web.Response:
        """
        POST /hook/sonarr or /hook/radarr — translate *arr webhook payloads.

        Sonarr/Radarr send their own event JSON (eventType, series/movie, etc.).
        The optional ?url= query parameter sets the click-through action URL
        (typically the *arr web UI on Tailscale).
        """
        try:
            payload = await request.json()
        except json.JSONDecodeError:
            return web.json_response({"error": "invalid JSON"}, status=400)

        action_url = request.query.get("url")
        event_type = payload.get("eventType", "Unknown")
        source = request.match_info.get("source", "arr")

        title, body, priority = self._format_arr_event(source, event_type, payload)

        try:
            event_id = await self._send_message(title, body, priority, action_url)
            return web.json_response({"event_id": event_id})
        except Exception as e:
            log.exception("Failed to relay %s webhook", source)
            return web.json_response({"error": str(e)}, status=502)

    @staticmethod
    def _format_arr_event(source: str, event_type: str, payload: dict):
        """
        Extract a human-readable title/body from a Sonarr or Radarr event payload.

        Returns (title, body, priority).
        """
        label = source.capitalize()
        priority = "normal"

        if source == "sonarr":
            series = payload.get("series", {}).get("title", "Unknown Series")
            episodes = payload.get("episodes", [])
            ep_info = ""
            if episodes:
                ep = episodes[0]
                ep_info = f"S{ep.get('seasonNumber', '?'):02d}E{ep.get('episodeNumber', '?'):02d}"
                ep_title = ep.get("title", "")
                if ep_title:
                    ep_info += f" — {ep_title}"

            if event_type == "Grab":
                quality = payload.get("release", {}).get("quality", "")
                body = f"Grabbing: {series} {ep_info}"
                if quality:
                    body += f" [{quality}]"
            elif event_type in ("Download", "EpisodeFileDelete"):
                file_path = payload.get("episodeFile", {}).get("relativePath", "")
                body = f"Downloaded: {series} {ep_info}"
                if file_path:
                    body += f"\n{file_path}"
            elif event_type == "SeriesAdd":
                body = f"Series added: {series}"
            elif event_type == "SeriesDelete":
                body = f"Series deleted: {series}"
            elif event_type == "Health":
                body = payload.get("message", "Health issue detected")
                priority = "high"
            elif event_type == "Test":
                body = "Webhook test successful"
            else:
                body = f"{event_type}: {series} {ep_info}".strip()

        elif source == "radarr":
            movie = payload.get("movie", {}).get("title", "Unknown Movie")
            year = payload.get("movie", {}).get("year", "")

            if event_type == "Grab":
                quality = payload.get("release", {}).get("quality", "")
                body = f"Grabbing: {movie} ({year})"
                if quality:
                    body += f" [{quality}]"
            elif event_type in ("Download", "MovieFileDelete"):
                file_path = payload.get("movieFile", {}).get("relativePath", "")
                body = f"Downloaded: {movie} ({year})"
                if file_path:
                    body += f"\n{file_path}"
            elif event_type == "MovieAdded":
                body = f"Movie added: {movie} ({year})"
            elif event_type == "MovieDelete":
                body = f"Movie deleted: {movie} ({year})"
            elif event_type == "Health":
                body = payload.get("message", "Health issue detected")
                priority = "high"
            elif event_type == "Test":
                body = "Webhook test successful"
            else:
                body = f"{event_type}: {movie} ({year})".strip()

        else:
            body = json.dumps(payload, indent=2)[:500]

        return (label, body, priority)

    async def handle_health(self, request: web.Request) -> web.Response:
        """GET /health — simple health check."""
        return web.json_response({"status": "ok"})

    # ── Server lifecycle ─────────────────────────────────────────────────

    async def start(self):
        """Start the HTTP server."""
        app = web.Application()
        app.router.add_post("/hook", self.handle_hook)
        app.router.add_post("/hook/{source}", self.handle_arr)
        app.router.add_get("/health", self.handle_health)

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, self.bind, self.port)
        await site.start()
        log.info("Listening on %s:%d", self.bind, self.port)

        # Run until cancelled
        try:
            await asyncio.Event().wait()
        except asyncio.CancelledError:
            pass
        finally:
            await runner.cleanup()
            if self._session:
                await self._session.close()

        log.info("Shutdown complete")


def main():
    parser = argparse.ArgumentParser(
        description="HTTP webhook → Matrix room relay",
    )
    parser.add_argument(
        "--homeserver",
        required=True,
        help="Matrix homeserver URL (e.g., http://localhost:8008)",
    )
    parser.add_argument(
        "--room",
        required=True,
        help="Room ID or alias to post to (e.g., #notifications:server or !abc:server)",
    )
    parser.add_argument(
        "--token-file",
        required=True,
        help="Path to file containing the bot's Matrix access token",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=9100,
        help="Port to listen on (default: 9100)",
    )
    parser.add_argument(
        "--bind",
        default="127.0.0.1",
        help="Address to bind to (default: 127.0.0.1)",
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

    relay = WebhookRelay(
        homeserver=args.homeserver,
        room_id=args.room,
        token_file=args.token_file,
        port=args.port,
        bind=args.bind,
    )

    loop = asyncio.new_event_loop()
    task = None

    def on_signal():
        if task:
            task.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, on_signal)

    try:
        task = loop.create_task(relay.start())
        loop.run_until_complete(task)
    except (asyncio.CancelledError, KeyboardInterrupt):
        pass
    finally:
        loop.close()


if __name__ == "__main__":
    main()
