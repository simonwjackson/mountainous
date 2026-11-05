"""Deterministic, device-pixel Platinum tokens (direction A).

Pure interface: render(source_frames, device_size, theme) -> RGBA image or None.
The favicon stays front-on. Only its body is extruded. Geometry follows the
approved exploration; the complete composite reserves margin(size) on each side.
"""

from collections.abc import Sequence

import numpy as np
from PIL import Image, ImageDraw

THEMES = ("platinum-light", "platinum-dark")


def margin(size: int) -> int:
    # Round halves up, unlike Python's round(2.5): 30 px must reserve 3 px.
    return max(2, (size + 6) // 12)


def mac_system_palette() -> np.ndarray:
    cube = (255, 204, 153, 102, 51, 0)
    ramp = (238, 221, 187, 170, 136, 119, 85, 68, 34, 17)
    return np.array(
        [(r, g, b) for r in cube for g in cube for b in cube]
        + [(v, 0, 0) for v in ramp]
        + [(0, v, 0) for v in ramp]
        + [(0, 0, v) for v in ramp]
        + [(v, v, v) for v in ramp],
        dtype=np.int32,
    )


PALETTE = mac_system_palette()


def quantize(rgb: np.ndarray) -> np.ndarray:
    """Nearest Mac colour, weighted RGB, fixed tie order, no dithering."""
    flat = rgb.reshape(-1, 3).astype(np.int32)
    out = np.empty_like(flat, dtype=np.uint8)
    # Bound temporary memory even for build-time 256 px callers.
    for start in range(0, len(flat), 1024):
        delta = flat[start : start + 1024, None, :] - PALETTE[None, :, :]
        distance = (delta * delta * (30, 59, 11)).sum(axis=-1)
        out[start : start + 1024] = PALETTE[distance.argmin(axis=-1)]
    return out.reshape(rgb.shape)


def select_frame(frames: Sequence[Image.Image], needed: int) -> Image.Image:
    """Smallest source covering the requested slot, else largest (favicon.js)."""
    ordered = sorted(frames, key=lambda frame: min(frame.size))
    return next((frame for frame in ordered if min(frame.size) >= needed), ordered[-1])


def shift(array: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(array)
    height, width = array.shape[:2]
    if abs(dx) >= width or abs(dy) >= height:
        return out
    xs, xd = (
        (slice(0, width - dx), slice(dx, width))
        if dx >= 0
        else (slice(-dx, width), slice(0, width + dx))
    )
    ys, yd = (
        (slice(0, height - dy), slice(dy, height))
        if dy >= 0
        else (slice(-dy, height), slice(0, height + dy))
    )
    out[yd, xd] = array[ys, xs]
    return out


def ring(mask: np.ndarray) -> np.ndarray:
    return (
        shift(mask, 1, 0) | shift(mask, -1, 0) | shift(mask, 0, 1) | shift(mask, 0, -1)
    ) & ~mask


def holes(mask: np.ndarray) -> np.ndarray:
    reach = np.zeros_like(mask)
    reach[0, :] = reach[-1, :] = reach[:, 0] = reach[:, -1] = True
    reach &= ~mask
    while True:
        expanded = (reach | ring(reach)) & ~mask
        if np.array_equal(expanded, reach):
            return ~mask & ~reach
        reach = expanded


def solidity(mask: np.ndarray) -> float:
    """Opaque area / convex hull area, using pixel corners, not centres."""
    ys, xs = np.nonzero(mask)
    points = sorted(
        {
            corner
            for x, y in zip(xs.tolist(), ys.tolist())
            for corner in ((x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1))
        }
    )
    if not points:
        return 0.0

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def half(sequence):
        hull = []
        for point in sequence:
            while len(hull) >= 2 and cross(hull[-2], hull[-1], point) <= 0:
                hull.pop()
            hull.append(point)
        return hull[:-1]

    hull = half(points) + half(reversed(points))
    area = (
        abs(
            sum(
                hull[i][0] * hull[i - 1][1] - hull[i - 1][0] * hull[i][1]
                for i in range(len(hull))
            )
        )
        / 2
    )
    return float(mask.sum()) / area if area else 0.0


def fit(source: Image.Image, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Trim transparent padding; preserve aspect ratio; hard alpha after sampling."""
    scale = size / max(source.size)
    dimensions = tuple(
        max(1, min(size, int(value * scale + 0.5))) for value in source.size
    )
    sampling = (
        Image.Resampling.LANCZOS
        if max(source.size) > size
        else Image.Resampling.NEAREST
    )
    image = source.convert("RGBa").resize(dimensions, sampling).convert("RGBA")
    canvas = Image.new("RGBA", (size, size))
    canvas.paste(image, ((size - image.width) // 2, (size - image.height) // 2))
    pixels = np.array(canvas)
    return pixels[:, :, :3], pixels[:, :, 3] >= 128


def render(
    frames: Sequence[Image.Image], size: int, theme: str = "platinum-light"
) -> Image.Image | None:
    """Use a light Platinum carrier in both modes, for dark-glyph contrast.

    Theme is explicit in the contract and cache key. Neither mode changes brand
    colours. Empty images return None so callers keep the current icon.
    """
    if not isinstance(size, int) or isinstance(size, bool) or not 8 <= size <= 256:
        raise ValueError("device size must be an integer from 8 to 256")
    if theme not in THEMES:
        raise ValueError("unknown Platinum icon theme")
    if not frames:
        return None
    source = select_frame(frames, size).convert("RGBA")
    alpha = source.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        return None
    source = source.crop(bounds)
    inner = size - 2 * margin(size)
    depth = min({24: 2, 30: 4, 48: 6}.get(size, max(2, size // 8)), max(1, inner // 4))
    shadow = 1 if size < 30 else 2
    face_size = inner - depth - 2 - shadow
    if face_size < 1:
        return None
    face, mask = fit(source, face_size)
    # Solidity alone calls a thin line a token. Only compact solid silhouettes
    # (squares, rounded squares, discs) get their own body; other marks get a plate.
    compact = min(source.size) / max(source.size) >= 0.75
    plate = not compact or solidity(mask) < 0.90
    body = np.zeros((inner, inner), dtype=bool)
    colours = np.zeros((inner, inner, 3), dtype=np.int32)
    x, y = 1, depth + 1
    if plate:
        plate_image = Image.new("L", (face_size, face_size))
        ImageDraw.Draw(plate_image).rounded_rectangle(
            (0, 0, face_size - 1, face_size - 1),
            radius=max(1, face_size // 9),
            fill=255,
        )
        body[y : y + face_size, x : x + face_size] = np.array(plate_image) >= 128
        colours[body] = 238
        inset = min(1 if size < 30 else 2, max(0, (face_size - 1) // 2))
        glyph_size = face_size - 2 * inset
        face, mask = fit(source, glyph_size)
        patch = colours[
            y + inset : y + inset + glyph_size, x + inset : x + inset + glyph_size
        ]
        patch[mask] = face[mask]
        side_colours = np.full_like(colours, 238)
    else:
        body[y : y + face_size, x : x + face_size] = mask
        colours[y : y + face_size, x : x + face_size] = face
        enclosed = holes(body)
        colours[enclosed] = 255
        body |= enclosed
        side_colours = colours
    extrusion = np.zeros_like(body)
    edge_colours = np.zeros_like(colours)
    for step in range(depth, 0, -1):
        moved = shift(body, step, -step) & ~body
        edge_colours[moved] = shift(side_colours, step, -step)[moved]
        extrusion |= moved
    top = np.zeros_like(body)
    ys, xs = np.nonzero(extrusion)
    for yy, xx in zip(ys, xs):
        vertical = next(
            (j for j in range(1, depth + 2) if yy + j < inner and body[yy + j, xx]),
            inner + 1,
        )
        horizontal = next(
            (j for j in range(1, depth + 2) if xx - j >= 0 and body[yy, xx - j]),
            inner + 1,
        )
        top[yy, xx] = vertical <= horizontal
    outline = ring(body | extrusion)
    whole = body | extrusion | outline
    cast = shift(whole, shadow, shadow) & ~whole
    output = np.zeros((inner, inner, 4), dtype=np.uint8)
    output[cast] = (0, 0, 0, 96)
    output[outline] = (0, 0, 0, 255)
    light = (
        np.full_like(edge_colours, 255) if plate else (edge_colours * 3 + 255 * 2) // 5
    )
    dark = np.full_like(edge_colours, 153) if plate else edge_colours * 55 // 100
    output[extrusion & top, :3] = light[extrusion & top]
    output[extrusion & ~top, :3] = dark[extrusion & ~top]
    output[extrusion, 3] = 255
    output[body, :3] = colours[body]
    output[body, 3] = 255
    output[:, :, :3] = quantize(output[:, :, :3])
    composite = Image.fromarray(output)
    # One rule for every source: centre the complete composite's bounds, never
    # tweak individual glyphs. Do not resize the finished pixel art.
    composite = composite.crop(composite.getbbox())
    result = Image.new("RGBA", (size, size))
    result.paste(
        composite, ((size - composite.width) // 2, (size - composite.height) // 2)
    )
    return result
