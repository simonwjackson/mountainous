"""Exact, repeatable image operations for OpenClaw agents.

Generative image models redraw the whole picture and cannot hit an exact page
size. These operations never redraw: they crop, pad, resize, trace and convert
pixels that already exist, with ImageMagick, resvg and potrace.

Every operation reads only from the configured read roots and writes a new file
into the output directory. It never overwrites a file. Failures raise
`KitError` with a `kind` the caller can show to the agent.
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

RASTER_FORMATS = {".png": "png", ".jpg": "jpeg", ".jpeg": "jpeg", ".webp": "webp", ".gif": "gif"}
MAX_INPUT_BYTES = 60 * 1024 * 1024
MAX_INPUT_PIXELS = 120_000_000
COMMAND_TIMEOUT_S = 120
# Bounds ImageMagick itself, so one call cannot exhaust the gateway's memory.
MAGICK_LIMITS = ["-limit", "memory", "768MiB", "-limit", "map", "1GiB", "-limit", "disk", "2GiB"]

# Width and height in inches, portrait.
PAPERS = {
    "letter": (8.5, 11.0),
    "legal": (8.5, 14.0),
    "tabloid": (11.0, 17.0),
    "a4": (210 / 25.4, 297 / 25.4),
    "a5": (148 / 25.4, 210 / 25.4),
    "a3": (297 / 25.4, 420 / 25.4),
}
GRAVITY = {
    "center": "center",
    "top": "north",
    "bottom": "south",
    "left": "west",
    "right": "east",
}


class KitError(Exception):
    """An operation failed. `kind` is one of: bad_input, not_allowed, too_large, tool_failed."""

    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind


@dataclass(frozen=True)
class Written:
    path: Path
    width: int
    height: int
    dpi: float

    def describe(self) -> str:
        if self.path.suffix == ".svg" or self.path.suffix == ".pdf":
            return str(self.path)
        size = f"{self.width}×{self.height} px"
        if self.dpi > 0:
            size += f", {self.dpi:g} dpi = {self.width / self.dpi:.2f}×{self.height / self.dpi:.2f} in"
        return f"{self.path} ({size})"


@dataclass(frozen=True)
class Kit:
    read_roots: tuple[Path, ...]
    out_dir: Path

    # ---- paths -------------------------------------------------------------

    def source(self, raw: str, allowed: dict[str, str] = RASTER_FORMATS) -> tuple[Path, str]:
        """Resolve an input path inside a read root and return it with its coder name."""
        if not isinstance(raw, str) or not raw.strip():
            raise KitError("bad_input", "path is required")
        raw = raw.strip().removeprefix("MEDIA:")
        candidate = Path(raw)
        if not candidate.is_absolute():
            candidate = self.read_roots[0] / candidate
        resolved = candidate.resolve()
        if not any(resolved.is_relative_to(root.resolve()) for root in self.read_roots):
            roots = ", ".join(str(root) for root in self.read_roots)
            raise KitError("not_allowed", f"{raw} is outside the readable folders ({roots})")
        if not resolved.is_file():
            raise KitError("bad_input", f"{raw} does not exist")
        coder = allowed.get(resolved.suffix.lower())
        if coder is None:
            raise KitError("bad_input", f"{resolved.name}: expected one of {', '.join(sorted(allowed))}")
        if resolved.stat().st_size > MAX_INPUT_BYTES:
            raise KitError("too_large", f"{resolved.name} is larger than {MAX_INPUT_BYTES // 2**20} MB")
        return resolved, coder

    def publish(self, temp: Path, stem: str, suffix: str) -> Path:
        """Move a finished temp file to a new name; never replace an existing file."""
        self.out_dir.mkdir(parents=True, exist_ok=True)
        safe = re.sub(r"[^A-Za-z0-9._-]+", "-", stem).strip("-.")[:80] or "image"
        for n in range(1, 1000):
            target = self.out_dir / (f"{safe}{suffix}" if n == 1 else f"{safe}-{n}{suffix}")
            try:
                os.link(temp, target)
            except FileExistsError:
                continue
            temp.unlink()
            return target
        raise KitError("tool_failed", f"no free file name for {safe}{suffix}")

    def temp(self, suffix: str) -> Path:
        self.out_dir.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(prefix=".kit-", suffix=suffix, dir=self.out_dir)
        os.close(fd)
        return Path(name)

    # ---- external tools ----------------------------------------------------

    @staticmethod
    def run(argv: list[str], stdin: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
        try:
            done = subprocess.run(argv, input=stdin, capture_output=True, timeout=COMMAND_TIMEOUT_S)
        except subprocess.TimeoutExpired as error:
            raise KitError("tool_failed", f"{argv[0]} took longer than {COMMAND_TIMEOUT_S} s") from error
        return done

    def magick(self, args: list[str]) -> None:
        done = self.run(["magick", *MAGICK_LIMITS, *args])
        if done.returncode != 0:
            raise KitError("tool_failed", "ImageMagick: " + done.stderr.decode(errors="replace").strip()[:500])

    def measure(self, path: Path, coder: str = "png") -> tuple[int, int, float]:
        done = self.run(["magick", "identify", "-units", "PixelsPerInch", "-format", "%w %h %x\n", f"{coder}:{path}[0]"])
        if done.returncode != 0:
            raise KitError("bad_input", f"{path.name} is not a readable image")
        width, height, dpi = done.stdout.decode().split()[:3]
        return int(width), int(height), float(dpi)

    def checked_source(self, raw: str) -> tuple[str, int, int, float, Path]:
        path, coder = self.source(raw)
        width, height, dpi = self.measure(path, coder)
        if width * height > MAX_INPUT_PIXELS:
            raise KitError("too_large", f"{path.name} has more than {MAX_INPUT_PIXELS // 1_000_000} megapixels")
        return f"{coder}:{path}[0]", width, height, dpi, path

    def finish(self, temp: Path, stem: str, suffix: str = ".png") -> Written:
        target = self.publish(temp, stem, suffix)
        if suffix in (".svg", ".pdf"):
            return Written(target, 0, 0, 0)
        width, height, dpi = self.measure(target)
        return Written(target, width, height, dpi)

    # ---- operations --------------------------------------------------------

    def info(self, path: str) -> str:
        _, width, height, dpi, resolved = self.checked_source(path)
        ratio = width / height
        nearest = min(
            ((name, orient, w / h) for name, (pw, ph) in PAPERS.items()
             for orient, (w, h) in (("portrait", (pw, ph)), ("landscape", (ph, pw)))),
            key=lambda paper: abs(paper[2] - ratio),
        )
        lines = [
            f"{resolved}: {width}×{height} px, width:height {ratio:.3f}",
            f"Closest paper shape: {nearest[0]} {nearest[1]} ({nearest[2]:.3f}).",
            f"At 300 dpi it prints at {width / 300:.2f}×{height / 300:.2f} in.",
        ]
        if dpi > 0:
            lines.append(f"Stored resolution: {dpi:g} dpi.")
        return "\n".join(lines)

    def fit_page(self, path: str, paper: str = "letter", orientation: str = "portrait",
                 mode: str = "pad", anchor: str = "center", background: str = "white",
                 dpi: int = 300) -> Written:
        if paper not in PAPERS:
            raise KitError("bad_input", f"paper must be one of {', '.join(PAPERS)}")
        if orientation not in ("portrait", "landscape"):
            raise KitError("bad_input", "orientation must be portrait or landscape")
        if mode not in ("pad", "crop"):
            raise KitError("bad_input", "mode must be pad (keep everything, add margin) or crop (fill, trim edges)")
        if anchor not in GRAVITY:
            raise KitError("bad_input", f"anchor must be one of {', '.join(GRAVITY)}")
        if background not in ("white", "transparent"):
            raise KitError("bad_input", "background must be white or transparent")
        if not 72 <= dpi <= 600:
            raise KitError("bad_input", "dpi must be between 72 and 600")
        source, _, _, _, resolved = self.checked_source(path)
        inches = PAPERS[paper] if orientation == "portrait" else PAPERS[paper][::-1]
        width, height = round(inches[0] * dpi), round(inches[1] * dpi)
        geometry = f"{width}x{height}" + ("^" if mode == "crop" else "")
        temp = self.temp(".png")
        self.magick([
            source, "-filter", "Lanczos", "-resize", geometry,
            "-background", "none" if background == "transparent" else "white",
            "-gravity", GRAVITY[anchor], "-extent", f"{width}x{height}",
            *([] if background == "transparent" else ["-flatten"]),
            "-units", "PixelsPerInch", "-density", str(dpi), f"png:{temp}",
        ])
        return self.finish(temp, f"{resolved.stem}-{paper}-{orientation}")

    def crop(self, path: str, left: float, top: float, width: float, height: float) -> Written:
        box = (left, top, width, height)
        if any(not isinstance(v, (int, float)) for v in box) or not (
            0 <= left < 1 and 0 <= top < 1 and 0 < width <= 1 - left + 1e-9 and 0 < height <= 1 - top + 1e-9
        ):
            raise KitError("bad_input", "left, top, width, height are fractions of the image (0–1) and must stay inside it")
        source, w, h, _, resolved = self.checked_source(path)
        px = [round(left * w), round(top * h), max(1, round(width * w)), max(1, round(height * h))]
        temp = self.temp(".png")
        self.magick([source, "-crop", f"{px[2]}x{px[3]}+{px[0]}+{px[1]}", "+repage", f"png:{temp}"])
        return self.finish(temp, f"{resolved.stem}-crop")

    def split(self, path: str, columns: int = 2, rows: int = 1) -> list[Written]:
        if not (isinstance(columns, int) and isinstance(rows, int) and 1 <= columns <= 6 and 1 <= rows <= 6 and columns * rows > 1):
            raise KitError("bad_input", "columns and rows are whole numbers 1–6, with more than one piece")
        source, _, _, _, resolved = self.checked_source(path)
        self.out_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".kit-", dir=self.out_dir) as scratch:
            pattern = Path(scratch) / "piece-%02d.png"
            self.magick([source, "-crop", f"{columns}x{rows}@", "+repage", "+adjoin", f"png:{pattern}"])
            pieces = sorted(Path(scratch).glob("piece-*.png"))
            results = []
            for index, piece in enumerate(pieces, start=1):
                temp = self.temp(".png")
                os.replace(piece, temp)
                results.append(self.finish(temp, f"{resolved.stem}-part{index}"))
        return results

    def enlarge(self, path: str, factor: float = 2, sharpen: bool = True) -> Written:
        if not isinstance(factor, (int, float)) or not 1 < factor <= 4:
            raise KitError("bad_input", "factor must be more than 1 and at most 4")
        source, w, h, dpi, resolved = self.checked_source(path)
        if w * h * factor * factor > MAX_INPUT_PIXELS:
            raise KitError("too_large", "the enlarged image would be too large; use a smaller factor")
        temp = self.temp(".png")
        self.magick([
            source, "-filter", "Lanczos", "-resize", f"{factor * 100:g}%",
            *(["-unsharp", "0x0.75+0.75+0.008"] if sharpen else []),
            "-units", "PixelsPerInch", "-density", f"{(dpi or 72) * factor:g}", f"png:{temp}",
        ])
        return self.finish(temp, f"{resolved.stem}-x{factor:g}")

    def make_transparent(self, path: str, tolerance: int = 12) -> Written:
        if not isinstance(tolerance, int) or not 0 <= tolerance <= 60:
            raise KitError("bad_input", "tolerance is a whole number 0–60 (percent)")
        source, _, _, _, resolved = self.checked_source(path)
        temp = self.temp(".png")
        self.magick([source, "-alpha", "set", "-fuzz", f"{tolerance}%", "-transparent", "white", f"png:{temp}"])
        return self.finish(temp, f"{resolved.stem}-transparent")

    def vectorize(self, path: str, threshold: int = 55) -> Written:
        if not isinstance(threshold, int) or not 5 <= threshold <= 95:
            raise KitError("bad_input", "threshold is a whole number 5–95 (percent brightness)")
        source, _, _, _, resolved = self.checked_source(path)
        bitmap = self.run(["magick", *MAGICK_LIMITS, source, "-background", "white", "-alpha", "remove",
                           "-colorspace", "gray", "-threshold", f"{threshold}%", "pbm:-"])
        if bitmap.returncode != 0:
            raise KitError("tool_failed", "ImageMagick: " + bitmap.stderr.decode(errors="replace").strip()[:500])
        temp = self.temp(".svg")
        traced = self.run(["potrace", "--svg", "--turdsize", "4", "--output", str(temp), "-"], stdin=bitmap.stdout)
        if traced.returncode != 0:
            temp.unlink(missing_ok=True)
            raise KitError("tool_failed", "potrace: " + traced.stderr.decode(errors="replace").strip()[:500])
        return self.finish(temp, f"{resolved.stem}-vector", ".svg")

    def render_svg(self, path: str, paper: str | None = None, orientation: str = "portrait",
                   width_px: int | None = None, background: str = "white", dpi: int = 300) -> Written:
        resolved, _ = self.source(path, {".svg": "svg"})
        if background not in ("white", "transparent"):
            raise KitError("bad_input", "background must be white or transparent")
        if not 72 <= dpi <= 600:
            raise KitError("bad_input", "dpi must be between 72 and 600")
        size: list[str]
        page: list[str] = []
        if paper is not None:
            if paper not in PAPERS or orientation not in ("portrait", "landscape"):
                raise KitError("bad_input", f"paper must be one of {', '.join(PAPERS)}; orientation portrait or landscape")
            inches = PAPERS[paper] if orientation == "portrait" else PAPERS[paper][::-1]
            width, height = round(inches[0] * dpi), round(inches[1] * dpi)
            # resvg keeps the drawing's own shape inside this box; extent pads it to the exact page.
            size = ["--width", str(width), "--height", str(height)]
            page = ["-background", "white" if background == "white" else "none", "-gravity", "center",
                    "-extent", f"{width}x{height}"]
        elif width_px is not None:
            if not isinstance(width_px, int) or not 16 <= width_px <= 8000:
                raise KitError("bad_input", "width_px must be 16–8000")
            size = ["--width", str(width_px)]
        else:
            size = ["--dpi", str(dpi)]
        raw = self.temp(".png")
        done = self.run(["resvg", *size, *(["--background", "white"] if background == "white" else []),
                         str(resolved), str(raw)])
        if done.returncode != 0:
            raw.unlink(missing_ok=True)
            raise KitError("tool_failed", "resvg: " + done.stderr.decode(errors="replace").strip()[:500])
        temp = self.temp(".png")
        self.magick([f"png:{raw}", *page, "-units", "PixelsPerInch", "-density", str(dpi), f"png:{temp}"])
        raw.unlink()
        return self.finish(temp, f"{resolved.stem}-render")

    def compare(self, before: str, after: str, box: list[float] | None = None) -> str:
        first, w1, h1, _, a = self.checked_source(before)
        second, w2, h2, _, b = self.checked_source(after)
        resize = [] if (w1, h1) == (w2, h2) else ["-resize", f"{w1}x{h1}!"]

        def mae(crop: list[str]) -> float:
            done = self.run(["magick", *MAGICK_LIMITS, first, *crop, "(", second, *resize, *crop, ")",
                             "-metric", "MAE", "-compare", "-format", "%[distortion]", "info:"])
            if done.returncode not in (0, 1):
                raise KitError("tool_failed", "ImageMagick: " + done.stderr.decode(errors="replace").strip()[:500])
            return float(done.stdout.decode().strip() or 0)

        whole = mae([])
        lines = [f"Whole image changed by {whole * 100:.2f}% (mean absolute difference)."]
        if resize:
            lines.append(f"Note: sizes differ ({w1}×{h1} vs {w2}×{h2}); the second was scaled to the first to compare.")
        if box is not None:
            if not (isinstance(box, list) and len(box) == 4 and all(isinstance(v, (int, float)) for v in box)):
                raise KitError("bad_input", "box is [left, top, width, height] as fractions 0–1")
            left, top, width, height = box
            if not (0 <= left < 1 and 0 <= top < 1 and 0 < width <= 1 - left + 1e-9 and 0 < height <= 1 - top + 1e-9):
                raise KitError("bad_input", "box must stay inside the image")
            crop = ["-crop", f"{max(1, round(width * w1))}x{max(1, round(height * h1))}+{round(left * w1)}+{round(top * h1)}", "+repage"]
            region = mae(crop)
            lines.append(f"Box changed by {region * 100:.2f}%.")
            ratio = region / whole if whole > 0 else float("inf")
            verdict = (
                "The edit landed mostly inside the box." if ratio >= 2.5
                else "The change is spread over the whole image: the model probably redrew everything." if ratio < 1.5
                else "Unclear: the box changed only a little more than the rest. Draw the box tighter and compare again."
            )
            lines.append(f"Box-to-whole ratio {ratio:.2f}. {verdict}")
        return f"{a.name} → {b.name}\n" + "\n".join(lines)

    def pdf(self, paths: list[str], paper: str = "letter", orientation: str = "portrait",
            name: str = "pages", dpi: int = 300) -> Written:
        if not isinstance(paths, list) or not 1 <= len(paths) <= 60:
            raise KitError("bad_input", "paths is a list of 1–60 images, in page order")
        if paper not in PAPERS or orientation not in ("portrait", "landscape"):
            raise KitError("bad_input", f"paper must be one of {', '.join(PAPERS)}; orientation portrait or landscape")
        sources = [self.checked_source(p)[0] for p in paths]
        inches = PAPERS[paper] if orientation == "portrait" else PAPERS[paper][::-1]
        width, height = round(inches[0] * dpi), round(inches[1] * dpi)
        temp = self.temp(".pdf")
        self.magick([
            *sources, "-filter", "Lanczos", "-resize", f"{width}x{height}", "-background", "white",
            "-gravity", "center", "-extent", f"{width}x{height}", "-alpha", "remove", "+repage",
            "-units", "PixelsPerInch", "-density", str(dpi), f"pdf:{temp}",
        ])
        return self.finish(temp, name, ".pdf")
