#!/usr/bin/env python3
"""Build the approved dialog PNGs with nixpkgs' librsvg and ChicagoFLF."""

import argparse
import subprocess
from pathlib import Path

import lockplan


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--host", required=True)
    parser.add_argument("--user", required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for appearance in lockplan.PAL:
        for variant in ("regular", "compact"):
            for scale in lockplan.PREBUILT_SCALES:
                svg, _ = lockplan.dialog_svg(
                    appearance, scale, variant, args.host, args.user
                )
                base = args.output / f"dialog-{appearance}-{variant}-s{scale}"
                source = Path(f"{base}.svg")
                source.write_text(svg)
                subprocess.run(
                    ["rsvg-convert", "-o", f"{base}.png", str(source)], check=True
                )
                source.unlink()


if __name__ == "__main__":
    main()
