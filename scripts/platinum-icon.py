#!/usr/bin/env python3
"""Fetch without browser cookies; print one atomic cached token path, or nothing."""

import argparse
import fcntl
import hashlib
import io
import os
import re
import signal
import struct
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import warnings
from pathlib import Path

from PIL import Image, UnidentifiedImageError
from platinum_icons import RENDER_VERSION, THEMES, render

MAX_SOURCE_BYTES = 2 * 1024 * 1024
MAX_SOURCE_PIXELS = 4 * 1024 * 1024
MAX_CACHE_FILES = 512
MAX_CACHE_BYTES = 32 * 1024 * 1024
CACHE_NAME = re.compile(r"[0-9a-f]{64}-[0-9]+-platinum-(light|dark)\.png$")
Image.MAX_IMAGE_PIXELS = MAX_SOURCE_PIXELS


class WebOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme not in ("http", "https"):
            raise ValueError("non-web favicon redirect")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def source_bytes(source: str) -> bytes:
    url = urllib.parse.urlsplit(source)
    if url.scheme in ("http", "https"):
        if url.username is not None or url.password is not None:
            raise ValueError("favicon URL must not include credentials")
        request = urllib.request.Request(
            source, headers={"User-Agent": "mountainous-icons/1", "Accept": "image/*"}
        )
        # No CookieJar, Authorization, Referer, browser profile or proxy credentials.
        opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), WebOnlyRedirect()
        )
        try:
            with opener.open(request, timeout=5) as response:
                data = response.read(MAX_SOURCE_BYTES + 1)
        except urllib.error.HTTPError as error:
            error.close()
            raise
    else:
        if url.scheme == "file" and url.netloc in ("", "localhost"):
            path = Path(urllib.parse.unquote(url.path))
        elif url.scheme == "" and Path(source).is_absolute():
            path = Path(source)
        else:
            raise ValueError("expected HTTP(S) URL or absolute local icon file")
        with path.open("rb") as stream:
            data = stream.read(MAX_SOURCE_BYTES + 1)
    if not data or len(data) > MAX_SOURCE_BYTES:
        raise ValueError("empty or oversized favicon")
    return data


def decode(data: bytes, size: int) -> list[Image.Image]:
    # rsvg defaults prohibit external resource references for stdin. Do not give
    # untrusted SVG a file base URL, --unlimited, or access to the PWA directory.
    if b"<svg" in data[:4096].lower():
        result = subprocess.run(
            [
                os.environ.get("RSVG_CONVERT", "rsvg-convert"),
                "--format=png",
                "--width=" + str(size),
                "--height=" + str(size),
                "--keep-aspect-ratio",
            ],
            input=data,
            capture_output=True,
            timeout=5,
            check=True,
        )
        data = result.stdout
    with warnings.catch_warnings():
        warnings.simplefilter("error", Image.DecompressionBombWarning)
        with Image.open(io.BytesIO(data)) as image:
            if image.width * image.height > MAX_SOURCE_PIXELS:
                raise ValueError("favicon dimensions exceed limit")
            if image.format == "ICO":
                sizes = sorted(image.ico.sizes(), key=min)
                if len(sizes) > 64:
                    raise ValueError("too many ICO frames")
                # Decode only the best resolution, using favicon.js's rule.
                # A hostile directory must not make us allocate 64 large images.
                chosen = next(
                    (dimensions for dimensions in sizes if min(dimensions) >= size),
                    sizes[-1],
                )
                return [image.ico.getimage(chosen).convert("RGBA")]
            # GIF, WebP, APNG: intentionally read only the first frame.
            image.seek(0)
            return [image.convert("RGBA")]


def prune(cache: Path, keep: Path) -> None:
    files = []
    for path in cache.iterdir():
        # Every writer holds .lock, so these can only be crash leftovers.
        if path.name.startswith(".token-") and path.suffix == ".png":
            path.unlink(missing_ok=True)
        if CACHE_NAME.fullmatch(path.name):
            try:
                stat = path.stat()
                files.append((path, stat.st_mtime_ns, stat.st_size))
            except FileNotFoundError:
                continue
    files.sort(key=lambda item: (item[0] != keep, -item[1], item[0].name))
    total = 0
    for index, (path, _, length) in enumerate(files):
        total += length
        if index >= MAX_CACHE_FILES or total > MAX_CACHE_BYTES:
            path.unlink(missing_ok=True)


def cached_icon(
    source: str, size: int, theme: str, cache: Path | None = None
) -> Path | None:
    if theme not in THEMES or not 8 <= size <= 256:
        raise ValueError("invalid icon size/theme")
    data = source_bytes(source)
    # The renderer version is part of the digest, so a new drawing gets new
    # names and the old files age out through the normal size limit.
    digest = hashlib.sha256(RENDER_VERSION.encode() + b"\0" + data).hexdigest()
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    if not cache_home.is_absolute():
        cache_home = Path.home() / ".cache"
    cache = cache or cache_home / "mountainous/icons"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    output = cache / f"{digest}-{size}-{theme}.png"
    # Lock pruning, cache hits and atomic publication together. Rendering is
    # bounded and small; concurrent surfaces cannot prune each other's writes.
    with (cache / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if output.is_file():
            output.touch()
            prune(cache, output)
            return output
        icon = render(decode(data, size), size, theme)
        if icon is None:
            return None
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(
                prefix=".token-", suffix=".png", dir=cache, delete=False
            ) as stream:
                temporary = Path(stream.name)
                icon.save(stream, format="PNG", optimize=False)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, output)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
        prune(cache, output)
        return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("size", type=int)
    parser.add_argument("theme", choices=THEMES)
    args = parser.parse_args()

    def deadline(_signal, _frame):
        raise TimeoutError("favicon request deadline")

    signal.signal(signal.SIGALRM, deadline)
    signal.alarm(12)
    try:
        path = cached_icon(args.source, args.size, args.theme)
        if path is not None:
            print(path)
    except (
        OSError,
        ValueError,
        subprocess.SubprocessError,
        EOFError,
        SyntaxError,
        struct.error,
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ):
        # Failure is an empty result, not an icon-shaped error. The caller keeps
        # today's favicon or installed icon, and the UI never waits for this CLI.
        return 0
    finally:
        signal.alarm(0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
