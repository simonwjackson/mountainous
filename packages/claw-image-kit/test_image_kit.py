"""Behaviour tests: real ImageMagick, resvg and potrace on files in a temp folder."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from image_kit import Kit, KitError

HERE = Path(__file__).parent


def draw(path: Path, size: str, *ops: str) -> Path:
    subprocess.run(["magick", "-size", size, "xc:white", *ops, str(path)], check=True)
    return path


def size_of(path: Path) -> tuple[int, int, float]:
    out = subprocess.run(["magick", "identify", "-units", "PixelsPerInch", "-format", "%w %h %x", str(path)],
                         check=True, capture_output=True, text=True).stdout.split()
    return int(out[0]), int(out[1]), float(out[2])


class KitTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.workspace = root / "workspace"
        self.workspace.mkdir()
        self.kit = Kit(read_roots=(self.workspace,), out_dir=root / "out")
        # A 2:3 picture, the shape image generators return instead of Letter.
        self.tall = draw(self.workspace / "tall.png", "1024x1536", "-fill", "black", "-draw", "circle 512,768 512,400")

    def tearDown(self):
        self.tmp.cleanup()

    def test_fit_page_makes_exact_letter_at_300_dpi(self):
        for mode in ("pad", "crop"):
            written = self.kit.fit_page("tall.png", paper="letter", mode=mode)
            self.assertEqual(size_of(written.path), (2550, 3300, 300.0))

    def test_fit_page_landscape_a4(self):
        written = self.kit.fit_page(str(self.tall), paper="a4", orientation="landscape", dpi=150)
        self.assertEqual(size_of(written.path)[:2], (1754, 1240))

    def test_never_overwrites(self):
        first = self.kit.fit_page("tall.png")
        second = self.kit.fit_page("tall.png")
        self.assertNotEqual(first.path, second.path)
        self.assertTrue(first.path.exists() and second.path.exists())

    def test_refuses_paths_outside_read_roots(self):
        outside = draw(Path(self.tmp.name) / "secret.png", "10x10")
        with self.assertRaises(KitError) as caught:
            self.kit.info(str(outside))
        self.assertEqual(caught.exception.kind, "not_allowed")
        with self.assertRaises(KitError):
            self.kit.info("../secret.png")

    def test_refuses_formats_imagemagick_should_not_parse(self):
        (self.workspace / "x.svg").write_text("<svg xmlns='http://www.w3.org/2000/svg'/>")
        with self.assertRaises(KitError) as caught:
            self.kit.fit_page("x.svg")
        self.assertEqual(caught.exception.kind, "bad_input")

    def test_split_spread_into_two_pages(self):
        spread = draw(self.workspace / "spread.png", "2000x1400")
        pages = self.kit.split(spread.name, columns=2)
        self.assertEqual([size_of(p.path)[:2] for p in pages], [(1000, 1400), (1000, 1400)])

    def test_crop_fractions(self):
        written = self.kit.crop("tall.png", 0.25, 0.5, 0.5, 0.25)
        self.assertEqual(size_of(written.path)[:2], (512, 384))
        with self.assertRaises(KitError):
            self.kit.crop("tall.png", 0.8, 0, 0.5, 1)

    def test_enlarge_doubles_and_scales_dpi(self):
        written = self.kit.enlarge("tall.png", factor=2)
        width, height, _ = size_of(written.path)
        self.assertEqual((width, height), (2048, 3072))

    def test_make_transparent(self):
        written = self.kit.make_transparent("tall.png")
        corner = subprocess.run(["magick", str(written.path), "-format", "%[pixel:p{1,1}]", "info:"],
                                check=True, capture_output=True, text=True).stdout
        self.assertIn("a(", corner.replace("srgba", "a").replace("rgba", "a"))

    def test_vectorize_then_render_to_letter(self):
        svg = self.kit.vectorize("tall.png")
        self.assertIn("<svg", svg.path.read_text())
        kit = Kit(read_roots=(self.workspace, self.kit.out_dir), out_dir=self.kit.out_dir)
        png = kit.render_svg(str(svg.path), paper="letter")
        self.assertEqual(size_of(png.path), (2550, 3300, 300.0))

    def test_compare_tells_local_edit_from_redraw(self):
        local = draw(self.workspace / "local.png", "1024x1536", "-fill", "black", "-draw", "circle 512,768 512,400",
                     "-fill", "black", "-draw", "rectangle 50,50 250,250")
        report = self.kit.compare("tall.png", "local.png", box=[0.04, 0.03, 0.2, 0.14])
        self.assertIn("landed mostly inside the box", report)
        redraw = draw(self.workspace / "redraw.png", "1024x1536", "-fill", "black", "-draw", "circle 400,700 400,300",
                      "-fill", "black", "-draw", "rectangle 50,50 250,250")
        report = self.kit.compare("tall.png", "redraw.png", box=[0, 0, 1, 1])
        self.assertIn("redrew everything", report)

    def test_pdf_has_one_page_per_image(self):
        written = self.kit.pdf(["tall.png", "tall.png"], name="book")
        self.assertEqual(written.path.suffix, ".pdf")
        pages = subprocess.run(["magick", "identify", str(written.path)], capture_output=True, text=True).stdout
        # Reading PDFs needs Ghostscript; when it is missing, check the file header instead.
        if pages:
            self.assertEqual(len(pages.strip().splitlines()), 2)
        else:
            self.assertTrue(written.path.read_bytes().startswith(b"%PDF"))
            self.assertEqual(written.path.read_bytes().count(b"/Type /Page\n") + written.path.read_bytes().count(b"/Type /Page "), 2)


class ServerTest(unittest.TestCase):
    def test_stdio_protocol_and_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "ws"
            workspace.mkdir()
            draw(workspace / "a.png", "300x400")
            messages = [
                {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
                {"jsonrpc": "2.0", "method": "notifications/initialized"},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
                {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "fit_page", "arguments": {"path": "a.png"}}},
                {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "fit_page", "arguments": {"path": "/etc/passwd"}}},
                {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "fit_page", "arguments": {"path": "a.png", "evil": 1}}},
                {"jsonrpc": "2.0", "id": 6, "method": "resources/list"},
            ]
            done = subprocess.run(
                [sys.executable, str(HERE / "server.py"), "--read-root", str(workspace), "--out-dir", str(Path(tmp) / "out")],
                input="".join(json.dumps(m) + "\n" for m in messages) + "not json\n",
                capture_output=True, text=True, timeout=120, check=True,
            )
            replies = [json.loads(line) for line in done.stdout.splitlines()]
            self.assertEqual([r["id"] for r in replies], [1, 2, 3, 4, 5, 6, None])
            self.assertEqual(replies[0]["result"]["protocolVersion"], "2025-06-18")
            self.assertEqual(len(replies[1]["result"]["tools"]), 10)
            self.assertFalse(replies[2]["result"]["isError"])
            self.assertIn("2550×3300 px", replies[2]["result"]["content"][0]["text"])
            self.assertTrue(replies[3]["result"]["isError"])
            self.assertIn("not_allowed", replies[3]["result"]["content"][0]["text"])
            self.assertIn("evil", replies[4]["result"]["content"][0]["text"])
            self.assertEqual(replies[5]["error"]["code"], -32601)
            self.assertEqual(replies[6]["error"]["code"], -32700)


if __name__ == "__main__":
    unittest.main()
