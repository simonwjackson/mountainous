"""MCP stdio server that exposes image_kit operations to an OpenClaw gateway.

Usage: server.py --read-root DIR [--read-root DIR ...] --out-dir DIR

Messages are newline-delimited JSON-RPC 2.0 on stdin and stdout. Only
initialize, ping, tools/list and tools/call are answered.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from image_kit import PAPERS, GRAVITY, Kit, KitError, Written

PROTOCOL_VERSIONS = ("2025-06-18", "2025-03-26", "2024-11-05")
SEND_HINT = "To show a file to the user, put MEDIA:<path> on its own line in your reply."

PATH = {"type": "string", "description": "Image path: absolute, or relative to the agent workspace. A MEDIA: prefix is accepted."}
PAPER = {"type": "string", "enum": list(PAPERS), "description": "Paper size."}
ORIENTATION = {"type": "string", "enum": ["portrait", "landscape"]}
DPI = {"type": "integer", "minimum": 72, "maximum": 600, "description": "Print resolution. Default 300."}
FRACTION = {"type": "number", "minimum": 0, "maximum": 1}


def schema(properties: dict, required: list[str]) -> dict:
    return {"type": "object", "properties": properties, "required": required, "additionalProperties": False}


TOOLS = [
    {
        "name": "image_info",
        "description": "Measure an image: pixel size, shape, closest paper size and printed size at 300 dpi. Use it before and after any change.",
        "inputSchema": schema({"path": PATH}, ["path"]),
    },
    {
        "name": "fit_page",
        "description": (
            "Make an image an exact paper size (e.g. US Letter 8.5×11 in at 300 dpi = 2550×3300 px) without redrawing it. "
            "Use this instead of asking the image generator for a page size: generators ignore exact sizes. "
            "mode=pad keeps the whole image and adds margin; mode=crop fills the page and trims the overflowing edges."
        ),
        "inputSchema": schema({
            "path": PATH, "paper": PAPER, "orientation": ORIENTATION,
            "mode": {"type": "string", "enum": ["pad", "crop"]},
            "anchor": {"type": "string", "enum": list(GRAVITY), "description": "Which part to keep when cropping, or where to place the image when padding."},
            "background": {"type": "string", "enum": ["white", "transparent"]},
            "dpi": DPI,
        }, ["path"]),
    },
    {
        "name": "crop",
        "description": "Cut out one exact rectangle. left, top, width and height are fractions of the image (0–1). Nothing is redrawn.",
        "inputSchema": schema({"path": PATH, "left": FRACTION, "top": FRACTION, "width": FRACTION, "height": FRACTION},
                              ["path", "left", "top", "width", "height"]),
    },
    {
        "name": "split",
        "description": "Cut an image into equal pieces, e.g. a two-page spread into 2 pages (columns=2). Nothing is redrawn.",
        "inputSchema": schema({
            "path": PATH,
            "columns": {"type": "integer", "minimum": 1, "maximum": 6},
            "rows": {"type": "integer", "minimum": 1, "maximum": 6},
        }, ["path"]),
    },
    {
        "name": "enlarge",
        "description": "Enlarge an image 1–4× with high-quality resampling, keeping every detail where it is. It adds no new detail. For black-and-white line art, vectorize gives sharper results at any size.",
        "inputSchema": schema({
            "path": PATH, "factor": {"type": "number", "exclusiveMinimum": 1, "maximum": 4},
            "sharpen": {"type": "boolean"},
        }, ["path"]),
    },
    {
        "name": "make_transparent",
        "description": "Turn the white background into transparency (PNG), so a piece can be layered in Canva or another editor.",
        "inputSchema": schema({"path": PATH, "tolerance": {"type": "integer", "minimum": 0, "maximum": 60, "description": "How close to white counts as background, in percent. Default 12."}}, ["path"]),
    },
    {
        "name": "vectorize",
        "description": "Trace black-and-white line art into an SVG that stays crisp at any size. Use render_svg to look at it or to make a print PNG.",
        "inputSchema": schema({"path": PATH, "threshold": {"type": "integer", "minimum": 5, "maximum": 95, "description": "Brightness below which a pixel counts as ink, in percent. Default 55."}}, ["path"]),
    },
    {
        "name": "render_svg",
        "description": "Render an SVG to PNG, at a paper size or a pixel width. Use it to check an SVG you wrote with view_image before sending it, because view_image cannot open SVG.",
        "inputSchema": schema({
            "path": {"type": "string", "description": "SVG path, absolute or relative to the agent workspace."},
            "paper": PAPER, "orientation": ORIENTATION,
            "width_px": {"type": "integer", "minimum": 16, "maximum": 8000},
            "background": {"type": "string", "enum": ["white", "transparent"]},
            "dpi": DPI,
        }, ["path"]),
    },
    {
        "name": "compare",
        "description": (
            "Check whether an edit did what was asked. Gives how much the whole image changed and, with box, how much a region changed. "
            "Draw the box tightly around the feature that should have changed."
        ),
        "inputSchema": schema({
            "before": PATH, "after": PATH,
            "box": {"type": "array", "items": FRACTION, "minItems": 4, "maxItems": 4, "description": "[left, top, width, height] as fractions 0–1."},
        }, ["before", "after"]),
    },
    {
        "name": "pdf",
        "description": "Combine images into one print-ready PDF, one image per page, each fitted to the paper size. Use it to give the user one file to print or open on a phone.",
        "inputSchema": schema({
            "paths": {"type": "array", "items": PATH, "minItems": 1, "maxItems": 60},
            "paper": PAPER, "orientation": ORIENTATION,
            "name": {"type": "string", "description": "File name without extension."},
            "dpi": DPI,
        }, ["paths"]),
    },
]


def call(kit: Kit, name: str, args: dict) -> str:
    def wrote(result: Written | list[Written]) -> str:
        files = result if isinstance(result, list) else [result]
        return "Wrote:\n" + "\n".join(f"- {item.describe()}" for item in files) + f"\n{SEND_HINT}"

    match name:
        case "image_info":
            return kit.info(**args)
        case "fit_page":
            return wrote(kit.fit_page(**args))
        case "crop":
            return wrote(kit.crop(**args))
        case "split":
            return wrote(kit.split(**args))
        case "enlarge":
            return wrote(kit.enlarge(**args))
        case "make_transparent":
            return wrote(kit.make_transparent(**args))
        case "vectorize":
            return wrote(kit.vectorize(**args))
        case "render_svg":
            return wrote(kit.render_svg(**args))
        case "compare":
            return kit.compare(**args)
        case "pdf":
            return wrote(kit.pdf(**args))
    raise KitError("bad_input", f"unknown tool {name}")


def handle(kit: Kit, message: dict) -> dict | None:
    method = message.get("method")
    if "id" not in message:
        return None  # A notification, such as notifications/initialized.
    reply: dict = {"jsonrpc": "2.0", "id": message["id"]}
    params = message.get("params") or {}
    if method == "initialize":
        asked = params.get("protocolVersion")
        reply["result"] = {
            "protocolVersion": asked if asked in PROTOCOL_VERSIONS else PROTOCOL_VERSIONS[0],
            "serverInfo": {"name": "claw-image-kit", "version": "1"},
            "capabilities": {"tools": {}},
        }
    elif method == "ping":
        reply["result"] = {}
    elif method == "tools/list":
        reply["result"] = {"tools": TOOLS}
    elif method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        known = {tool["name"]: tool for tool in TOOLS}
        try:
            if name not in known:
                raise KitError("bad_input", f"unknown tool {name}")
            allowed = set(known[name]["inputSchema"]["properties"])
            extra = set(args) - allowed
            if not isinstance(args, dict) or extra:
                raise KitError("bad_input", f"unknown arguments: {', '.join(sorted(extra))}")
            text, failed = call(kit, name, args), False
        except KitError as error:
            text, failed = f"{error.kind}: {error}", True
        except TypeError as error:
            text, failed = f"bad_input: {error}", True
        reply["result"] = {"content": [{"type": "text", "text": text}], "isError": failed}
    else:
        reply["error"] = {"code": -32601, "message": f"method not found: {method}"}
    return reply


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--read-root", action="append", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    options = parser.parse_args()
    kit = Kit(read_roots=tuple(options.read_root), out_dir=options.out_dir)
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError
        except ValueError:
            response: dict | None = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}}
        else:
            response = handle(kit, message)
        if response is not None:
            sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
