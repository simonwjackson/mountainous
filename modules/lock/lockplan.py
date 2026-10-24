#!/usr/bin/env python3
"""Lock screen plan: the one function that decides the art and the hyprlock config.

The mock (index.html) renders the widget lists this module emits, and the
lock-time wrapper (mountainous-lock) would write the same config. So the
picture and the config are the same decision, made once.

Units: every number that reaches hyprlock is a buffer (physical) pixel.
hyprlock 0.9.6 does not scale widget sizes, positions or font sizes by the
output scale (CSessionLockSurface::configure makes the buffer logical*scale,
and the widgets read that buffer size as their viewport). So each scale needs
its own numbers and its own dialog PNG.
"""

import math
import struct
import zlib

# ---------------------------------------------------------------- tokens
# Approved Platinum mock tokens. Keep PNG geometry and live widgets together.
PAL = {
    "light": dict(
        face="#dddddd",
        hi="#ffffff",
        lo="#999999",
        frame="#000000",
        text="#000000",
        text2="#3a3a3a",
        well="#ffffff",
        ring="#000000",
        raised="#e6e6e6",
        sel="#333399",
        danger="#9e2525",
        warn="#7a4d12",
        stripe_lo="#999999",
        stripe_hi="#ffffff",
        btn_ring="#000000",
        tint_check="#ccccff",
        tint_fail="#f2c2c2",
        tint_caps="#f3dfae",
    ),
    "grey": dict(
        face="#363636",
        hi="#565656",
        lo="#1e1e1e",
        frame="#000000",
        text="#ececec",
        text2="#b8b8b8",
        well="#242424",
        ring="#000000",
        raised="#444444",
        sel="#5858d0",
        danger="#ef8f8f",
        warn="#d5a66f",
        stripe_lo="#1e1e1e",
        stripe_hi="#565656",
        btn_ring="#000000",
        tint_check="#3c3c78",
        tint_fail="#5c2a2a",
        tint_caps="#4f4022",
    ),
}
# Extra dark: pure black screen, the dark grey dialog, compact.
PAL["extra"] = dict(PAL["grey"], frame="#5c5c5c")

# Desktop patterns. One bit = 2 logical px, so 3 device px at scale 1.5:
# 3 px at Myoko's 215 PPI is 0.354 mm, the size of one 72 dpi Mac pixel.
PATTERNS = {
    # Two staggered peaks per 16x16 tile. L = lit face, S = shade face.
    "peaks": [
        "................",
        "................",
        "....L...........",
        "...LLS..........",
        "..LLSSS.........",
        ".LLSSSSS........",
        "................",
        "................",
        "................",
        "................",
        "............L...",
        "...........LLS..",
        "..........LLSSS.",
        ".........LLSSSSS",
        "................",
        "................",
    ],
    # A quiet two-tone basket weave on an 8x8 tile.
    "weave": [
        "LLLLS.S.",
        "....S.S.",
        "LLLLS.S.",
        "....S.S.",
        "S.S.LLLL",
        "S.S.....",
        "S.S.LLLL",
        "S.S.....",
    ],
    "solid": ["."],
}
PATTERN_COLORS = {
    "light": {".": "#9a9cbc", "L": "#aeb0cc", "S": "#8a8cae"},
    "grey": {".": "#262628", "L": "#2f2f32", "S": "#1f1f21"},
}


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def hl_color(h):
    return "rgb(%s)" % h.lstrip("#")


# ---------------------------------------------------------------- metrics
def metrics(scale, variant):
    """Dialog geometry in device px for one scale and one variant.

    variant: 'regular' or 'compact'. Compact yields space first (padding,
    gaps, the title bar), then the icon shrinks; no element goes away.
    """

    def L(v):
        return int(round(v * scale))

    hair = max(1, int(round(scale * 1.34)))  # 1 at 1.0, 2 at 1.5, 3 at 2.0
    compact = variant == "compact"
    m = dict(scale=scale, variant=variant, hair=hair)
    m["font_px"] = L(12)  # Chicago 12: the system size
    # Small text (date, status): whole points, since label font_size is an int.
    m["small_pt"] = {1.0: 9, 1.25: 10, 1.5: 12, 2.0: 16}.get(
        scale, int(round(8 * scale))
    )
    m["small_px"] = round(m["small_pt"] * 4 / 3, 2)
    # Bullets: hyprlock asks pango for round(h * dots_size * 0.5) * 2 pt, an even number.
    m["dots_pt"] = 2 * int(round(m["font_px"] * 0.75 / 2 + 0.25))
    m["title_h"] = L(14 if compact else 20)
    m["pad"] = L(14 if compact else 22)
    m["icon_bit"] = hair if not compact else max(1, hair - (1 if scale >= 1.5 else 0))
    m["icon"] = 32 * m["icon_bit"]
    m["gap"] = L(12 if compact else 16)
    m["line"] = L(18)  # message line pitch
    m["field_inner_w"] = L(260 if compact else 300)
    m["field_inner_h"] = L(24)
    if m["field_inner_h"] % 2:
        m["field_inner_h"] += 1
    m["status_h"] = L(18)
    m["btn_w"] = L(72)
    m["btn_h"] = L(20)
    m["btn_ring_gap"] = hair // 2 if hair > 1 else 1
    m["btn_ring_w"] = hair * 2 if scale >= 1.5 else 3
    m["btn_radius"] = L(4)
    return m


def layout(scale, variant):
    """Positions of every part of the dialog, relative to its top-left."""
    m = metrics(scale, variant)
    h = m["hair"]
    edge = 2 * h  # frame + bevel
    g = dict(m)
    g["title"] = (edge, edge, None, m["title_h"])  # width filled below
    body_top = edge + m["title_h"] + h  # separator under the title
    x0 = edge + m["pad"]
    y0 = body_top + m["pad"]
    g["icon_xy"] = (x0, y0)
    x1 = x0 + m["icon"] + m["gap"]
    g["text_x"] = x1
    g["msg1_y"] = y0
    g["msg2_y"] = y0 + m["line"]
    # Field well: bevel, ring (drawn by hyprlock), inner box.
    well_top = y0 + 2 * m["line"] + int(round(6 * scale))
    g["well"] = (x1, well_top, m["field_inner_w"] + 4 * h, m["field_inner_h"] + 4 * h)
    g["field_inner"] = (
        x1 + 2 * h,
        well_top + 2 * h,
        m["field_inner_w"],
        m["field_inner_h"],
    )
    status_top = well_top + g["well"][3] + int(round(4 * scale))
    g["status"] = (x1, status_top, g["well"][2], m["status_h"])
    ring = m["btn_ring_gap"] + m["btn_ring_w"]
    btn_top = status_top + m["status_h"] + int(round(4 * scale)) + ring
    right = x1 + g["well"][2]
    g["button"] = (right - ring - m["btn_w"], btn_top, m["btn_w"], m["btn_h"])
    g["button_ring"] = (
        right - 2 * ring - m["btn_w"],
        btn_top - ring,
        m["btn_w"] + 2 * ring,
        m["btn_h"] + 2 * ring,
    )
    g["clock_mid_y"] = btn_top + m["btn_h"] // 2
    W = right + m["pad"] + edge
    H = btn_top + m["btn_h"] + ring + m["pad"] + edge
    g["W"], g["H"] = W, H
    g["title"] = (edge, edge, W - 2 * edge, m["title_h"])
    g["body_top"] = body_top
    return g


# ---------------------------------------------------------------- icon
def padlock_bits():
    """An original 32x32 padlock: steel shackle, brass body, keyhole.

    Drawn from shapes, then outlined, so it is nobody's artwork.
    Returns 32 strings. K outline, W white, codes for fills.
    """
    N = 32
    grid = [["." for _ in range(N)] for _ in range(N)]
    cx, cy = 15.5, 12.0
    for y in range(N):
        for x in range(N):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            # Shackle: half ring above cy, legs below it.
            if y <= cy and 5.0 <= r <= 9.0 and y >= 2:
                grid[y][x] = "s" if dx < 1 else "t"
            if cy < y <= 16 and (6.5 <= x <= 10.5 or 20.5 <= x <= 24.5):
                grid[y][x] = "s" if x < 16 else "t"
    for y in range(15, 30):
        for x in range(4, 28):
            corner = x in (4, 27) and y in (15, 29)
            if corner:
                continue
            # Brass, lit from the top left.
            if y == 15 or x == 4:
                c = "h"
            elif y >= 28 or x >= 26:
                c = "d"
            elif x + (y - 15) < 18:
                c = "b"
            else:
                c = "m"
            grid[y][x] = c
    # Engraved band across the body.
    for x in range(5, 26):
        grid[18][x] = "d"
        grid[19][x] = "h"
    # Keyhole.
    for y in range(21, 28):
        for x in range(13, 19):
            dx, dy = x - 15.5, y - 23.0
            if math.hypot(dx, dy) <= 2.1 or (y >= 23 and 15 <= x <= 16):
                grid[y][x] = "k"
    # Outline: any empty pixel that touches a filled pixel (4-neighbour).
    out = [row[:] for row in grid]
    for y in range(N):
        for x in range(N):
            if grid[y][x] != ".":
                continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < N and 0 <= yy < N and grid[yy][xx] not in (".",):
                    out[y][x] = "K"
                    break
    return ["".join(r) for r in out]


ICON_COLORS = {
    "K": "#000000",
    "s": "#d8d8e0",
    "t": "#8c8c98",
    "h": "#f4dc8c",
    "b": "#d9b44a",
    "m": "#b98f2a",
    "d": "#7a5a14",
    "k": "#000000",
}


# ---------------------------------------------------------------- dialog SVG
def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def dialog_svg(appearance, scale, variant, host="Myoko", user="simon"):
    p = PAL[appearance]
    g = layout(scale, variant)
    h, W, H = g["hair"], g["W"], g["H"]
    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" shape-rendering="crispEdges">'
        % (W, H, W, H)
    ]

    def R(x, y, w, hh, c):
        return out.append(
            '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (x, y, w, hh, c)
        )

    # Frame, then the raised window bevel, then the face.
    R(0, 0, W, H, p["frame"])
    R(h, h, W - 2 * h, H - 2 * h, p["lo"])
    R(h, h, W - 3 * h, H - 3 * h, p["hi"])
    R(2 * h, 2 * h, W - 4 * h, H - 4 * h, p["face"])
    # Title bar: grooves across the whole bar (untitled movable modal).
    tx, ty, tw, th = g["title"]
    inset = int(round(4 * scale))
    n = 6 if variant == "regular" else 4
    pitch = 2 * h
    total = n * pitch - h
    sy = ty + (th - total) // 2
    for i in range(n):
        R(tx + inset, sy + i * pitch, tw - 2 * inset, h, p["stripe_hi"])
        R(
            tx + inset + h, sy + i * pitch + h, tw - 2 * inset - h, h, p["stripe_lo"]
        ) if h else None
    # Separator under the title bar.
    R(2 * h, g["body_top"] - h, W - 4 * h, h, p["lo"])
    # Icon, one rect per bit.
    ix, iy = g["icon_xy"]
    b = g["icon_bit"]
    for yy, row in enumerate(padlock_bits()):
        for xx, c in enumerate(row):
            if c != ".":
                R(ix + xx * b, iy + yy * b, b, b, ICON_COLORS[c])
    # Messages.
    fp = g["font_px"]
    asc = 0.988 * fp
    lh = 1.188 * fp

    def text(x, y_top, s, color, size=fp, anchor="start"):
        base = y_top + (g["line"] - lh * size / fp) / 2 + 0.988 * size
        out.append(
            '<text x="%s" y="%.2f" font-family="ChicagoFLF" font-size="%d" fill="%s" text-anchor="%s" text-rendering="geometricPrecision">%s</text>'
            % (x, base, size, color, anchor, esc(s))
        )

    text(g["text_x"], g["msg1_y"], "%s is locked." % host, p["text"])
    text(g["text_x"], g["msg2_y"], "Enter the password for %s:" % user, p["text"])
    # Field well: sunken bevel; the ring and the inner box are hyprlock's,
    # drawn here too so a one-pixel miss shows nothing.
    wx, wy, ww, wh = g["well"]
    R(wx, wy, ww, wh, p["hi"])
    R(wx, wy, ww - h, wh - h, p["lo"])
    R(wx + h, wy + h, ww - 2 * h, wh - 2 * h, p["ring"])
    fx, fy, fw, fh = g["field_inner"]
    R(fx, fy, fw, fh, p["well"])
    # Default button: thick ring, then the button.
    rx, ry, rw, rh = g["button_ring"]
    rr = g["btn_radius"] + g["btn_ring_gap"] + g["btn_ring_w"]
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (rx, ry, rw, rh, rr, p["btn_ring"])
    )
    gi = g["btn_ring_w"]
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (rx + gi, ry + gi, rw - 2 * gi, rh - 2 * gi, rr - gi, p["face"])
    )
    bx, by, bw, bh = g["button"]
    br = g["btn_radius"]
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (bx, by, bw, bh, br, p["frame"] if appearance != "extra" else "#000000")
    )
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (bx + h, by + h, bw - 2 * h, bh - 2 * h, max(0, br - h), p["lo"])
    )
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (bx + h, by + h, bw - 3 * h, bh - 3 * h, max(0, br - h), p["hi"])
    )
    out.append(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" shape-rendering="geometricPrecision"/>'
        % (
            bx + 2 * h,
            by + 2 * h,
            bw - 4 * h,
            bh - 4 * h,
            max(0, br - 2 * h),
            p["raised"],
        )
    )
    base = by + (bh - lh) / 2 + asc
    out.append(
        '<text x="%.1f" y="%.2f" font-family="ChicagoFLF" font-size="%d" fill="%s" text-anchor="middle" text-rendering="geometricPrecision">Unlock</text>'
        % (bx + bw / 2, base, fp, p["text"])
    )
    out.append("</svg>")
    return "\n".join(out), g


# ---------------------------------------------------------------- PNG writer
def write_png(path, w, h, rows_fn, palette):
    """Palette PNG, so a full-screen pattern stays small and fast."""

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += rows_fn(y)
    plte = b"".join(bytes(hex2rgb(c)) for c in palette)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 3, 0, 0, 0))
        + chunk(b"PLTE", plte)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 6))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as file:
        file.write(data)
    return len(data)


def pattern_png(path, name, appearance, w, h, scale):
    """Tile the pattern to w x h device px; one bit = 2 logical px."""
    bits = PATTERNS[name]
    cols = PATTERN_COLORS["grey" if appearance != "light" else "light"]
    keys = list(cols)
    pal = [cols[k] for k in keys]
    bit = max(1, int(round(2 * scale)))
    tw, th = len(bits[0]) * bit, len(bits) * bit
    rows = []
    for ty in range(th):
        r = bits[ty // bit]
        row = bytes(keys.index(r[(x // bit) % len(r)]) for x in range(tw))
        reps = w // tw + 1
        rows.append((row * reps)[:w])
    return write_png(path, w, h, lambda y: rows[y % th], pal)


# ---------------------------------------------------------------- appearance
def appearance_from_state(theme, extra):
    """theme: 'light'|'dark'; extra: 'on'|'off' (the two state files)."""
    if theme == "light":
        return "light"
    return "extra" if extra == "on" else "grey"


# ---------------------------------------------------------------- plan
FIT_MARGIN_LOGICAL = 24  # the dialog keeps this much screen around it

PREBUILT_SCALES = (1.0, 1.25, 1.5, 2.0)


def plan(
    monitors,
    appearance,
    pattern,
    art_dir="assets",
    prebuilt_scales=PREBUILT_SCALES,
    bg_dir=None,
):
    """monitors: hyprctl -j monitors style dicts: name, width, height, scale,
    focused, transform. Returns the widget list and the config text."""
    widgets = []
    if appearance == "extra":
        pattern = "solid"
    for mon in monitors:
        W, H = mon["width"], mon["height"]
        if mon.get("transform", 0) % 2 == 1:
            W, H = H, W
        s = mon["scale"]
        name = mon["name"]
        pal = PAL[appearance]
        cols = PATTERN_COLORS["light" if appearance == "light" else "grey"]
        bg_color = "#000000" if appearance == "extra" else cols["."]
        bg = dict(type="background", monitor=name, color=bg_color, path="")
        if appearance != "extra" and pattern != "solid":
            # Generated at lock time for this exact size (about 15 ms), so it
            # draws 1:1; hyprlock would scale any other size with GL_LINEAR.
            bg["path"] = "%s/bg-%s-%s-%dx%d-s%s.png" % (
                bg_dir or art_dir,
                pattern,
                appearance,
                W,
                H,
                s,
            )
            bg["gen"] = dict(pattern=pattern, appearance=appearance, w=W, h=H, scale=s)
        widgets.append(bg)
        if not (mon.get("focused") or name.startswith("eDP-")):
            continue
        # Intrinsic step: regular if it fits with margin, else compact.
        ds = min(prebuilt_scales, key=lambda x: abs(x - s))
        variant = "compact" if appearance == "extra" else "regular"
        g = layout(ds, variant)
        margin = int(FIT_MARGIN_LOGICAL * s)
        if g["W"] + 2 * margin > W or g["H"] + 2 * margin > H:
            variant = "compact"
            g = layout(ds, variant)
        # Mac alert position: centred across, a third of the way down.
        X = (W - g["W"]) // 2
        Y = max(margin, (H - g["H"]) // 3)
        widgets.append(
            dict(
                type="image",
                monitor=name,
                path="%s/dialog-%s-%s-s%s.png" % (art_dir, appearance, variant, ds),
                x=X,
                y=Y,
                w=g["W"],
                h=g["H"],
                size=min(g["W"], g["H"]),
                scale_mismatch=(ds != s),
            )
        )
        fx, fy, fw, fh = g["field_inner"]
        dots_pt = g["dots_pt"]
        dots_size = round((dots_pt / 2 + 0.01) / (fh * 0.5), 3)
        fail_pt1024 = int(round(g["font_px"] * 0.75 * 1024))
        widgets.append(
            dict(
                type="input-field",
                monitor=name,
                x=X + fx,
                y=Y + fy,
                w=fw,
                h=fh,
                inner=pal["well"],
                font=pal["text"],
                outline_thickness=0,
                check=pal["tint_check"],
                fail=pal["tint_fail"],
                caps=pal["tint_caps"],
                dots_size=dots_size,
                dots_pt=dots_pt,
                fail_text_size=fail_pt1024,
                fail_text="Wrong password.",
            )
        )

        def lh(px):
            return int(round(1.188 * px))

        sp = g["small_px"]
        small_pt = g["small_pt"]
        # Date and time: left, centred on the button row.
        widgets.append(
            dict(
                type="label",
                monitor=name,
                role="clock",
                x=X + g["text_x"],
                y=Y + g["clock_mid_y"] - lh(sp) // 2,
                px=sp,
                pt=small_pt,
                color=pal["text2"],
                text="cmd[update:1000] date +'%a, %b %-d  %-I:%M %p'",
            )
        )
        sx, sy, sw, shh = g["status"]
        widgets.append(
            dict(
                type="label",
                monitor=name,
                role="attempts",
                x=X + sx,
                y=Y + sy + (shh - lh(sp)) // 2,
                px=sp,
                pt=small_pt,
                color=pal["danger"],
                text='cmd[update:0:1] case $ATTEMPTS in 0) ;; 1) echo "1 failed attempt" ;; *) echo "$ATTEMPTS failed attempts" ;; esac',
            )
        )
    return widgets


def conf_text(widgets):
    """The hyprlock.conf the wrapper writes. Positions: halign=left,
    valign=top, so position = x, -y in device px (hyprlock's y points up)."""
    L = [
        "# Written by mountainous-lock at lock time. hyprlock 0.9.6, hyprlang syntax.",
        "general {",
        "    hide_cursor = false",
        "    ignore_empty_input = true    # Return on an empty field is not an attempt",
        "    fail_timeout = 3000          # ms the field shows the fail state",
        "    fractional_scaling = 2",
        "}",
        "animations {",
        "    enabled = true",
        "}",
        "animation = fadeIn, 1, 3, default",
        "animation = fadeOut, 1, 3, default",
        "animation = inputFieldColors, 1, 2, linear",
        "animation = inputFieldDots, 0",
        "animation = inputFieldWidth, 0",
        "",
    ]
    for w in widgets:
        t = w["type"]
        if t == "background":
            L += [
                "background {",
                "    monitor = %s" % w["monitor"],
                "    color = %s" % hl_color(w["color"]),
                "    path = %s" % w["path"],
                "    blur_passes = 0",
                "}",
            ]
        elif t == "image":
            L += [
                "image {",
                "    monitor = %s" % w["monitor"],
                "    path = %s" % w["path"],
                "    size = %d          # the PNG's lesser side, so it draws 1:1"
                % w["size"],
                "    rounding = 0       # default -1 is a circle",
                "    border_size = 0",
                "    position = %d, %d" % (w["x"], -w["y"]),
                "    halign = left",
                "    valign = top",
                "    zindex = 1",
                "}",
            ]
        elif t == "input-field":
            L += [
                "input-field {",
                "    monitor = %s" % w["monitor"],
                "    size = %d, %d" % (w["w"], w["h"]),
                "    position = %d, %d" % (w["x"], -w["y"]),
                "    halign = left",
                "    valign = top",
                "    zindex = 2",
                "    outline_thickness = 0      # states tint the PNG field well",
                "    rounding = 0",
                "    inner_color = %s" % hl_color(w["inner"]),
            ] + [
                "    font_color = %s" % hl_color(w["font"]),
                "    font_family = ChicagoFLF",
                "    dots_text_format = \u2022",
                "    dots_size = %s     # %d pt bullet"
                % (w["dots_size"], w["dots_pt"]),
                "    dots_spacing = 0",
                "    dots_center = false",
                "    fade_on_empty = false",
                "    placeholder_text =",
                "    check_text =",
                "    check_color = %s" % hl_color(w["check"]),
                "    fail_color = %s" % hl_color(w["fail"]),
                "    capslock_color = %s" % hl_color(w["caps"]),
                '    fail_text = <span size="%d">%s</span>'
                % (w["fail_text_size"], w["fail_text"]),
                "    shadow_passes = 0",
                "}",
            ]
        elif t == "label":
            pos_x = w["x"]
            hal = "left"
            pt = w["pt"]
            L += [
                "label {",
                "    monitor = %s" % w["monitor"],
                "    text = %s" % w["text"],
                "    font_family = ChicagoFLF",
                "    font_size = %d       # pt at 96 dpi: %s px" % (round(pt), w["px"]),
                "    color = %s" % hl_color(w["color"]),
                "    position = %d, %d" % (pos_x, -w["y"]),
                "    halign = %s" % hal,
                "    valign = top",
                "    zindex = 2",
                "}",
            ]
        L.append("")
    return "\n".join(L)
