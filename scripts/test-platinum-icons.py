#!/usr/bin/env python3
"""Synthetic original fixtures: no third-party favicon redistribution rights needed."""

import concurrent.futures
import hashlib
import http.server
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from platinum_icons import (
    PALETTE,
    RENDER_VERSION,
    boxed,
    canvas_for,
    margin,
    opaque_extent,
    render,
    render_extent,
    select_frame,
)

spec = importlib.util.spec_from_file_location(
    "platinum_cache", Path(__file__).with_name("platinum-icon.py")
)
cache_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache_helper)
spec = importlib.util.spec_from_file_location(
    "platinum_app_tokens", Path(__file__).with_name("platinum-app-tokens.py")
)
app_tokens = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app_tokens)


def corpus():
    fixtures = {}
    for shape in [
        "square",
        "rounded-square",
        "disc",
        "ring",
        "thin-glyph",
        "full-bleed",
        "tiny-padded",
        "wide",
        "16-only",
    ]:
        size = (
            (96, 32)
            if shape == "wide"
            else (16, 16)
            if shape == "16-only"
            else (64, 64)
        )
        image = Image.new("RGBA", size)
        draw = ImageDraw.Draw(image)
        colour = (39, 113, 213, 255)
        if shape in ["full-bleed", "16-only", "wide"]:
            draw.rectangle((0, 0, size[0] - 1, size[1] - 1), fill=colour)
        elif shape == "square":
            draw.rectangle((4, 4, 59, 59), fill=colour)
        elif shape == "rounded-square":
            draw.rounded_rectangle((4, 4, 59, 59), radius=12, fill=colour)
        elif shape in ["disc", "ring"]:
            draw.ellipse((4, 4, 59, 59), fill=colour)
            if shape == "ring":
                draw.ellipse((13, 13, 50, 50), fill=(0, 0, 0, 0))
        elif shape == "thin-glyph":
            draw.line((7, 7, 7, 56, 56, 56), fill=colour, width=3)
        elif shape == "tiny-padded":
            draw.line((30, 29, 30, 34, 34, 34), fill=colour, width=1)
        fixtures[shape] = image
    return fixtures


class RendererTests(unittest.TestCase):
    def test_margin_rounding(self):
        self.assertEqual([margin(size) for size in [24, 30, 36, 48]], [2, 2, 2, 3])

    def test_corpus_margin_full_inner_box_and_determinism(self):
        for name, image in corpus().items():
            for size in [24, 30, 36, 48]:
                for theme in ["platinum-light", "platinum-dark"]:
                    with self.subTest(name=name, size=size, theme=theme):
                        first = render([image], size, theme)
                        second = render([image], size, theme)
                        self.assertIsNotNone(first)
                        self.assertEqual(first.mode, "RGBA")
                        self.assertEqual(first.size, (size, size))
                        self.assertEqual(first.tobytes(), second.tobytes())
                        a, b = io.BytesIO(), io.BytesIO()
                        first.save(a, format="PNG")
                        second.save(b, format="PNG")
                        self.assertEqual(a.getvalue(), b.getvalue())
                        m = margin(size)
                        alpha = np.array(first)[:, :, 3]
                        self.assertFalse(alpha[:m].any())
                        self.assertFalse(alpha[-m:].any())
                        self.assertFalse(alpha[:, :m].any())
                        self.assertFalse(alpha[:, -m:].any())
                        # The whole composite, not only the front, uses the box.
                        self.assertEqual(first.getbbox(), (m, m, size - m, size - m))
                        self.assertTrue(set(np.unique(alpha)).issubset({0, 96, 255}))
                        palette = set(map(tuple, PALETTE.tolist()))
                        self.assertTrue(
                            set(
                                map(
                                    tuple,
                                    np.array(first)[:, :, :3].reshape(-1, 3).tolist(),
                                )
                            ).issubset(palette)
                        )

    def test_transparent_padding_does_not_shrink_the_glyph(self):
        glyph = corpus()["tiny-padded"]
        cropped = glyph.crop(glyph.getbbox())
        for size in [24, 30, 36, 48]:
            self.assertEqual(
                render([glyph], size).tobytes(), render([cropped], size).tobytes()
            )

    def test_frame_selection(self):
        frames = [
            Image.new("RGBA", (s, s), c)
            for s, c in [(64, "red"), (16, "green"), (32, "blue")]
        ]
        self.assertEqual(select_frame(frames, 24).size, (32, 32))
        self.assertEqual(select_frame(frames, 32).size, (32, 32))
        self.assertEqual(select_frame(frames, 48).size, (64, 64))
        self.assertEqual(select_frame(frames, 96).size, (64, 64))

    def test_invalid_or_empty_input(self):
        self.assertIsNone(render([], 24))
        self.assertIsNone(render([Image.new("RGBA", (32, 32))], 24))
        for size in [0, 7, 513]:
            with self.assertRaises(ValueError):
                render([corpus()["square"]], size)
        with self.assertRaises(ValueError):
            render([corpus()["square"]], 24, "memphis")


class OpticalSizeTests(unittest.TestCase):
    """The Control Strip's one optical size (strip-plan.js tileGeometry):
    every token's opaque bounds the same extent, centred, never resized."""

    def test_every_shape_has_the_extent_centred(self):
        palette = set(map(tuple, PALETTE.tolist()))
        for name, image in corpus().items():
            for extent in [18, 22, 26, 36]:
                for theme in ["platinum-light", "platinum-dark"]:
                    with self.subTest(name=name, extent=extent, theme=theme):
                        size = canvas_for(extent)
                        token = render_extent([image], extent, theme=theme)
                        self.assertEqual(token.size, (size, size))
                        self.assertEqual(
                            token.tobytes(),
                            render_extent([image], extent, theme=theme).tobytes(),
                        )
                        width, height = opaque_extent(token)
                        self.assertEqual(max(width, height), extent)
                        left, top, _, _ = token.getbbox()
                        self.assertEqual(
                            (left, top), ((size - width) // 2, (size - height) // 2)
                        )
                        m = margin(size)
                        alpha = np.array(token)[:, :, 3]
                        self.assertFalse(alpha[:m].any() or alpha[-m:].any())
                        self.assertFalse(alpha[:, :m].any() or alpha[:, -m:].any())
                        self.assertTrue(set(np.unique(alpha)).issubset({0, 96, 255}))
                        rgb = np.array(token)[:, :, :3].reshape(-1, 3).tolist()
                        self.assertTrue(set(map(tuple, rgb)).issubset(palette))

    def test_the_pixels_are_a_rendered_token_unscaled(self):
        # The same pixels as render() at some token size, moved, not resized.
        for name, image in corpus().items():
            with self.subTest(name=name):
                token = render_extent([image], 26)
                art = token.crop(token.getbbox()).tobytes()
                self.assertTrue(
                    any(
                        (r := render([image], size)) is not None
                        and r.crop(r.getbbox()).tobytes() == art
                        for size in range(26, 40)
                    )
                )

    def test_a_larger_canvas_and_bad_input(self):
        token = render_extent([corpus()["disc"]], 26, 36)
        self.assertEqual(token.size, (36, 36))
        self.assertEqual(token.getbbox(), (5, 5, 31, 31))
        self.assertEqual(
            token.crop((5, 5, 31, 31)).tobytes(),
            render_extent([corpus()["disc"]], 26).crop((2, 2, 28, 28)).tobytes(),
        )
        with self.assertRaises(ValueError):
            render_extent([corpus()["disc"]], 26, 29)
        self.assertIsNone(render_extent([], 26))
        self.assertIsNone(render_extent([Image.new("RGBA", (32, 32))], 26))

    def test_padded_theme_art_reaches_the_extent(self):
        # Platinum's 32 px art has empty space of its own (the cube: 23 px
        # of body); its token still has the one optical size.
        art = Image.new("RGBA", (32, 32))
        draw = ImageDraw.Draw(art)
        draw.rectangle((3, 12, 18, 27), fill=(200, 200, 200, 255), outline=(0, 0, 0, 255))
        draw.polygon([(19, 28), (26, 21), (30, 21), (30, 24), (24, 30), (19, 30)], fill=(0, 0, 0, 80))
        self.assertEqual(max(opaque_extent(render_extent([art], 26))), 26)


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.cache = self.directory / "cache"
        self.source = self.directory / "source.png"
        corpus()["square"].save(self.source)

    def test_content_address_atomic_concurrent_and_failure(self):
        def call(_):
            return cache_helper.cached_icon(
                str(self.source), 30, "platinum-dark", self.cache
            )

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            paths = list(pool.map(call, range(8)))
        expected = (
            hashlib.sha256(
                RENDER_VERSION.encode() + b"\0" + self.source.read_bytes()
            ).hexdigest()
            + "-30-platinum-dark.png"
        )
        self.assertTrue(all(path.name == expected for path in paths))
        with Image.open(paths[0]) as icon:
            self.assertEqual(icon.size, (30, 30))
        self.assertEqual(
            sorted(p.name for p in self.cache.iterdir()), [".lock", expected]
        )
        same = self.directory / "renamed.png"
        same.write_bytes(self.source.read_bytes())
        self.assertEqual(
            cache_helper.cached_icon(same.as_uri(), 30, "platinum-dark", self.cache),
            paths[0],
        )
        # A changed source at the same URL/path gets a new content key.
        corpus()["disc"].save(self.source)
        self.assertNotEqual(call(0), paths[0])
        self.source.write_bytes(b"not an image")
        command = (
            [os.environ["PLATINUM_ICON"]]
            if "PLATINUM_ICON" in os.environ
            else [sys.executable, str(Path(__file__).with_name("platinum-icon.py"))]
        )
        result = subprocess.run(
            command + [str(self.source), "30", "platinum-dark"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_extent_is_part_of_the_key(self):
        plain = cache_helper.cached_icon(str(self.source), 30, "platinum-light", self.cache)
        optical = cache_helper.cached_icon(
            str(self.source), 30, "platinum-light", self.cache, extent=26
        )
        digest = hashlib.sha256(
            RENDER_VERSION.encode() + b"\0" + self.source.read_bytes()
        ).hexdigest()
        self.assertEqual(plain.name, digest + "-30-platinum-light.png")
        self.assertEqual(optical.name, digest + "-30e26-platinum-light.png")
        self.assertTrue(cache_helper.CACHE_NAME.fullmatch(optical.name))
        with Image.open(optical) as icon:
            self.assertEqual(icon.size, (30, 30))
            self.assertEqual(opaque_extent(icon), (26, 26))
            self.assertEqual(icon.getbbox(), (2, 2, 28, 28))
        with Image.open(plain) as icon:
            self.assertEqual(opaque_extent(icon), (26, 26))
        with self.assertRaises(ValueError):
            cache_helper.cached_icon(str(self.source), 30, "platinum-light", self.cache, extent=27)
        command = (
            [os.environ["PLATINUM_ICON"]]
            if "PLATINUM_ICON" in os.environ
            else [sys.executable, str(Path(__file__).with_name("platinum-icon.py"))]
        )
        env = dict(os.environ, XDG_CACHE_HOME=str(self.directory / "xdg"))
        result = subprocess.run(
            command + [str(self.source), "30", "platinum-dark", "--extent", "24"],
            capture_output=True,
            text=True,
            check=True,
            env=env,
        )
        path = Path(result.stdout.strip())
        self.assertTrue(path.name.endswith("-30e24-platinum-dark.png"), path)
        with Image.open(path) as icon:
            self.assertEqual(max(opaque_extent(icon)), 24)

    def test_ico_png_svg_and_animation(self):
        # Each ICO frame has a different colour so selection is observable.
        frames = [
            Image.new("RGBA", (s, s), c)
            for s, c in [(16, "red"), (32, "blue"), (64, "green")]
        ]
        encoded = io.BytesIO()
        frames[-1].save(
            encoded,
            format="ICO",
            sizes=[(16, 16), (32, 32), (64, 64)],
            append_images=frames[:-1],
        )
        decoded = cache_helper.decode(encoded.getvalue(), 24)
        self.assertEqual(select_frame(decoded, 24).size, (32, 32))
        self.assertEqual(select_frame(decoded, 24).getpixel((0, 0)), (0, 0, 255, 255))
        svg = b'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32"><rect width="64" height="32" fill="red"/></svg>'
        svg_frames = cache_helper.decode(svg, 48)
        self.assertEqual(svg_frames[0].size, (48, 24))
        animation = io.BytesIO()
        frames[0].save(
            animation,
            format="GIF",
            save_all=True,
            append_images=[frames[1].resize((16, 16))],
            duration=50,
            loop=0,
        )
        self.assertEqual(
            cache_helper.decode(animation.getvalue(), 24)[0].getpixel((0, 0)),
            (255, 0, 0, 255),
        )
        self.assertEqual(
            cache_helper.decode(self.source.read_bytes(), 24)[0].size, (64, 64)
        )

    def test_lru_count_and_byte_limits(self):
        self.cache.mkdir()
        # Exercise the actual production bounds without generating 513 images.
        for index in range(cache_helper.MAX_CACHE_FILES + 2):
            path = self.cache / f"{index:064x}-24-platinum-light.png"
            path.write_bytes(b"png")
            os.utime(path, ns=(index + 1, index + 1))
        keep = self.cache / f"{0:064x}-24-platinum-light.png"
        cache_helper.prune(self.cache, keep)
        self.assertTrue(keep.exists())
        self.assertFalse((self.cache / f"{1:064x}-24-platinum-light.png").exists())
        self.assertEqual(
            len(list(self.cache.glob("*.png"))), cache_helper.MAX_CACHE_FILES
        )
        huge = self.cache / f"{'f' * 64}-48-platinum-dark.png"
        with huge.open("wb") as stream:
            stream.truncate(cache_helper.MAX_CACHE_BYTES + 1)
        cache_helper.prune(self.cache, keep)
        self.assertFalse(huge.exists())

    def test_http_has_no_cookies_and_bad_inputs_fail(self):
        received = []
        data = self.source.read_bytes()

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                received.append(dict(self.headers))
                if self.path == "/missing":
                    self.send_error(404)
                    return
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header("Location", "file:///etc/passwd")
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header("Set-Cookie", "private=value")
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *_):
                pass

        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f"http://127.0.0.1:{server.server_port}"
                for _ in range(2):
                    self.assertEqual(cache_helper.source_bytes(url), data)
                self.assertTrue(
                    all(
                        "Cookie" not in headers and "Authorization" not in headers
                        for headers in received
                    )
                )
                for path in ["/missing", "/redirect"]:
                    with self.assertRaises((OSError, ValueError)):
                        cache_helper.source_bytes(url + path)
            finally:
                server.shutdown()
                thread.join()
        for source in [
            "ftp://host/icon",
            "file://other/etc/passwd",
            "relative.png",
            "http://name:password@localhost/icon",
        ]:
            with self.assertRaises(ValueError):
                cache_helper.source_bytes(source)
        oversized = self.directory / "large"
        with oversized.open("wb") as stream:
            stream.truncate(cache_helper.MAX_SOURCE_BYTES + 1)
        with self.assertRaises(ValueError):
            cache_helper.source_bytes(str(oversized))


class StripArtTests(unittest.TestCase):
    """The Control Strip's one content box (strip-plan.js tileGeometry): a
    token's inner box, which is 32 px at scale 1.5, Platinum's art size."""

    def test_canvas_for_inner_box(self):
        # The smallest such token: 36 for the strip's 32 px box at scale 1.5.
        self.assertEqual(
            [canvas_for(box) for box in [20, 26, 32, 64]], [24, 30, 36, 72]
        )
        for box in [20, 26, 32, 42, 64]:
            size = canvas_for(box)
            self.assertEqual(size - 2 * margin(size), box)

    def test_boxed_is_the_token_without_its_margin(self):
        for name, image in corpus().items():
            with self.subTest(name=name):
                token = render([image], 36)
                art = boxed([image], 32)
                self.assertEqual(art.size, (32, 32))
                self.assertEqual(art.tobytes(), token.crop((2, 2, 34, 34)).tobytes())
                # Nothing of the token is lost: it fills the box exactly.
                self.assertEqual(art.getbbox(), (0, 0, 32, 32))
        self.assertIsNone(boxed([Image.new("RGBA", (32, 32))], 32))

    def test_build_time_tokens_for_apps_without_32_px_art(self):
        with tempfile.TemporaryDirectory() as temp:
            share = Path(temp) / "share"
            apps = share / "applications"
            apps.mkdir(parents=True)

            def entry(name, icon):
                (apps / f"{name}.desktop").write_text(
                    f"[Desktop Entry]\nType=Application\nName={name}\nExec=true\nIcon={icon}\n"
                )

            # Platinum art exists: no token. hicolor PNGs (16 and 128): the
            # 128 is chosen. Only a 16 px PNG: the largest. Only an SVG.
            # A pixmap. A path, a symbolic glyph and a missing icon: skipped.
            covering = Path(temp) / "Mountainous-platinum"
            (covering / "32x32/apps").mkdir(parents=True)
            Image.new("RGBA", (32, 32), "red").save(covering / "32x32/apps/themed.png")
            entry("themed", "themed")
            for size in (16, 128):
                directory = share / f"icons/hicolor/{size}x{size}/apps"
                directory.mkdir(parents=True, exist_ok=True)
                corpus()["disc"].resize((size, size)).save(directory / "multi.png")
            entry("multi", "multi")
            small = share / "icons/hicolor/16x16/apps"
            corpus()["16-only"].save(small / "small.png")
            entry("small", "small")
            scalable = share / "icons/hicolor/scalable/apps"
            scalable.mkdir(parents=True)
            (scalable / "vector.svg").write_text(
                '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48">'
                '<rect x="4" y="4" width="40" height="40" rx="8" fill="#2771d5"/></svg>'
            )
            entry("vector", "vector")
            (share / "pixmaps").mkdir()
            corpus()["rounded-square"].save(share / "pixmaps/legacy.png")
            entry("legacy", "legacy")
            entry("path", str(share / "pixmaps/legacy.png"))
            entry("glyph", "mark-location-symbolic")
            entry("missing", "nowhere")
            out = Path(temp) / "out"
            made = app_tokens.generate(share, out, [covering])
            self.assertEqual(made, ["legacy", "multi", "small", "vector"])
            files = sorted(p.name for p in (out / "32x32/apps").iterdir())
            self.assertEqual(files, ["legacy.png", "multi.png", "small.png", "vector.png"])
            for name in files:
                with Image.open(out / "32x32/apps" / name) as image:
                    self.assertEqual(image.size, (32, 32))
                    self.assertEqual(image.mode, "RGBA")
            # The same pixels the run-time token has inside its margin.
            with Image.open(out / "32x32/apps/multi.png") as image:
                frames = [
                    Image.open(share / f"icons/hicolor/{s}x{s}/apps/multi.png").convert("RGBA")
                    for s in (16, 128)
                ]
                self.assertEqual(image.tobytes(), boxed(frames, 32).tobytes())
            index = (out / "index.theme").read_text()
            self.assertIn("Directories=32x32/apps", index)
            self.assertIn("Size=32", index)
            self.assertIn("Type=Fixed", index)
            # Deterministic: a second run writes the same bytes.
            again = Path(temp) / "again"
            app_tokens.generate(share, again, [covering])
            for name in files + ["../../index.theme"]:
                self.assertEqual(
                    (out / "32x32/apps" / name).read_bytes(),
                    (again / "32x32/apps" / name).read_bytes(),
                )


    def test_strip_tokens_for_every_app_the_strip_can_show(self):
        self.assertEqual([app_tokens.strip_extent(s) for s in (1, 1.25, 1.5, 1.75, 2)], [18, 22, 26, 30, 36])
        with tempfile.TemporaryDirectory() as temp:
            share = Path(temp) / "share"
            apps = share / "applications"
            apps.mkdir(parents=True)

            def entry(name, icon):
                (apps / f"{name}.desktop").write_text(
                    f"[Desktop Entry]\nType=Application\nName={name}\nExec=true\nIcon={icon}\n"
                )

            covering = Path(temp) / "Mountainous-platinum"
            (covering / "32x32/apps").mkdir(parents=True)
            (covering / "32x32/mimes").mkdir(parents=True)
            # Theme art for chromium (padded, as the cube) and another
            # app; the generic fallback is a mime icon linked from apps.
            cube = Image.new("RGBA", (32, 32))
            ImageDraw.Draw(cube).rectangle((3, 12, 18, 27), fill="grey", outline="black")
            cube.save(covering / "32x32/apps/chromium.png")
            cube.save(covering / "32x32/apps/themed.png")
            corpus()["square"].resize((32, 32)).save(covering / "32x32/mimes/application-x-executable.png")
            (covering / "32x32/apps/application-x-executable.png").symlink_to("../mimes/application-x-executable.png")
            # Competing upstream icons must not replace the theme's art.
            hicolor = share / "icons/hicolor/256x256/apps"
            hicolor.mkdir(parents=True)
            for name in ("chromium", "themed", "application-x-executable"):
                corpus()["disc"].resize((256, 256)).save(hicolor / f"{name}.png")
            entry("chromium-browser", "chromium")
            corpus()["ring"].save(hicolor / "own.png")
            entry("own", "own")
            entry("glyph", "mark-location-symbolic")
            out = Path(temp) / "out"
            app_tokens.generate(share, out, [covering], scales=(1, 1.5))
            index = (out / "index.theme").read_text()
            self.assertIn("Directories=32x32/apps,22x22/apps,30x30/apps\n", index)
            self.assertIn("[30x30/apps]\nSize=30\nContext=Applications\nType=Fixed\n", index)
            for directory, extent in (("22x22/apps", 18), ("30x30/apps", 26)):
                names = sorted(p.name for p in (out / directory).iterdir())
                self.assertEqual(
                    names,
                    [
                        "mountainous.strip.application-x-executable.png",
                        "mountainous.strip.chromium.png",
                        "mountainous.strip.own.png",
                        "mountainous.strip.themed.png",
                    ],
                )
                size = canvas_for(extent)
                for name in names:
                    with Image.open(out / directory / name) as image:
                        self.assertEqual(image.size, (size, size))
                        self.assertEqual(max(opaque_extent(image)), extent, name)
            # Both scales use theme art first, including the symlinked generic
            # fallback. Only an app with no theme art uses its hicolor icon.
            for directory, extent in (("22x22/apps", 18), ("30x30/apps", 26)):
                for name in ("chromium", "themed", "application-x-executable", "own"):
                    source = (
                        hicolor / "own.png"
                        if name == "own"
                        else covering / "32x32/apps" / f"{name}.png"
                    )
                    with Image.open(source) as image:
                        expected = render_extent([image.convert("RGBA")], extent)
                    with Image.open(
                        out / directory / f"mountainous.strip.{name}.png"
                    ) as image:
                        self.assertEqual(image.tobytes(), expected.tobytes(), name)
            again = Path(temp) / "again"
            app_tokens.generate(share, again, [covering], scales=(1, 1.5))
            for file in sorted((out / "30x30/apps").iterdir()):
                self.assertEqual(file.read_bytes(), (again / "30x30/apps" / file.name).read_bytes())


if __name__ == "__main__":
    unittest.main()
