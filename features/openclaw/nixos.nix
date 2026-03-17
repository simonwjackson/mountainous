{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.openclaw;

  # Pollinations image generation script
  pollinations-generate = pkgs.writeScriptBin "pollinations-generate" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    usage() {
      echo "Usage: $0 --prompt TEXT --filename NAME [--width N] [--height N] [--seed N]"
      exit 1
    }

    PROMPT=""
    FILENAME=""
    WIDTH=1024
    HEIGHT=1024
    SEED=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --prompt) PROMPT="$2"; shift 2 ;;
        --filename) FILENAME="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; usage ;;
      esac
    done

    [[ -z "$PROMPT" ]] && echo "Error: --prompt is required" && usage
    [[ -z "$FILENAME" ]] && echo "Error: --filename is required" && usage

    ENCODED=$(${pkgs.python3}/bin/python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$PROMPT")

    URL="https://image.pollinations.ai/prompt/''${ENCODED}?width=''${WIDTH}&height=''${HEIGHT}"
    [[ -n "$SEED" ]] && URL="''${URL}&seed=''${SEED}"

    echo "Generating image..."
    echo "Size: ''${WIDTH}x''${HEIGHT}"

    HTTP_CODE=$(${pkgs.curl}/bin/curl -sL \
      -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
      -o "$FILENAME" -w "%{http_code}" "$URL")

    if [[ "$HTTP_CODE" == "200" ]] && [[ -f "$FILENAME" ]] && [[ -s "$FILENAME" ]]; then
      echo "Saved: $(pwd)/$FILENAME"
    else
      echo "Error: HTTP $HTTP_CODE — generation failed"
      rm -f "$FILENAME"
      exit 1
    fi
  '';

  # Hugging Face image generation script
  huggingface-generate = let
    python = pkgs.python3.withPackages (ps: [ps.requests]);
  in
    pkgs.writeScriptBin "huggingface-generate" ''
      #!${python}/bin/python3
      """Generate images using Hugging Face Inference API."""

      import argparse
      import os
      import sys
      import time
      import requests

      MODELS = {
          "flux-schnell": "black-forest-labs/FLUX.1-schnell",
          "flux-dev": "black-forest-labs/FLUX.1-dev",
          "sdxl": "stabilityai/stable-diffusion-xl-base-1.0",
          "sd3": "stabilityai/stable-diffusion-3-medium-diffusers",
      }

      DEFAULT_MODEL = "flux-schnell"
      API_URL = "https://api-inference.huggingface.co/models/{model}"


      def main():
          parser = argparse.ArgumentParser(description="Generate images via Hugging Face")
          parser.add_argument("--prompt", required=True, help="Image description")
          parser.add_argument("--filename", required=True, help="Output filename")
          parser.add_argument("--model", default=DEFAULT_MODEL, choices=list(MODELS.keys()),
                              help=f"Model to use (default: {DEFAULT_MODEL})")
          parser.add_argument("--negative-prompt", default=None, help="What to avoid")
          parser.add_argument("--width", type=int, default=1024)
          parser.add_argument("--height", type=int, default=1024)
          parser.add_argument("--seed", type=int, default=None)
          parser.add_argument("--api-key", default=None, help="HF token (or set HF_TOKEN env)")
          args = parser.parse_args()

          token = args.api_key or os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
          if not token:
              token_file = os.environ.get("HF_TOKEN_FILE", "")
              if token_file and os.path.isfile(token_file):
                  token = open(token_file).read().strip()
          if not token:
              print("Error: No API token. Set HF_TOKEN, HF_TOKEN_FILE, or pass --api-key", file=sys.stderr)
              sys.exit(1)

          model_id = MODELS[args.model]
          url = API_URL.format(model=model_id)

          payload = {"inputs": args.prompt}
          parameters = {}
          if args.negative_prompt:
              parameters["negative_prompt"] = args.negative_prompt
          if args.width:
              parameters["width"] = args.width
          if args.height:
              parameters["height"] = args.height
          if args.seed is not None:
              parameters["seed"] = args.seed
          if parameters:
              payload["parameters"] = parameters

          headers = {"Authorization": f"Bearer {token}"}

          print(f"Generating image...")
          print(f"Model: {args.model} ({model_id})")
          print(f"Size: {args.width}x{args.height}")

          resp = requests.post(url, headers=headers, json=payload, timeout=120)

          if resp.status_code == 503:
              print("Model is loading... retrying in 30s")
              time.sleep(30)
              resp = requests.post(url, headers=headers, json=payload, timeout=120)

          if resp.status_code != 200:
              print(f"Error: HTTP {resp.status_code}", file=sys.stderr)
              try:
                  print(resp.json(), file=sys.stderr)
              except Exception:
                  print(resp.text[:500], file=sys.stderr)
              sys.exit(1)

          with open(args.filename, "wb") as f:
              f.write(resp.content)

          print(f"Saved: {os.path.abspath(args.filename)}")


      if __name__ == "__main__":
          main()
    '';

  # SKILL.md files reference {baseDir} which OpenClaw replaces at runtime
  pollinations-skill = pkgs.writeTextDir "pollinations/SKILL.md" ''
    ---
    name: pollinations
    description: Generate images with Pollinations.ai (FLUX model). Free, no API key. Use for any image generation request.
    ---

    # Pollinations Image Generation

    Free, no API key, no signup. Uses FLUX by default.

    ## Usage

    ```bash
    ${pollinations-generate}/bin/pollinations-generate --prompt "your description" --filename "output.jpg" [--width N] [--height N] [--seed N]
    ```

    **Important:** Always run from the user's current working directory.

    ## Options

    - `--prompt` (required) — Image description
    - `--filename` (required) — Output filename (JPEG)
    - `--width` — Width in pixels (default: 1024)
    - `--height` — Height in pixels (default: 1024)
    - `--seed` — Seed for reproducibility

    ## Resolution Guide

    - Square: 1024×1024 (default)
    - Landscape: 1344×768
    - Portrait: 768×1344

    ## Filename Format

    `{timestamp}-{descriptive-name}.jpg` (e.g., `2026-02-18-03-00-00-sunset.jpg`)
  '';

  huggingface-skill = pkgs.writeTextDir "huggingface-image/SKILL.md" ''
    ---
    name: huggingface-image
    description: Generate images with Hugging Face Inference API (FLUX, SDXL). Free tier. Use for image generation requests.
    metadata: {"openclaw":{"requires":{"env":["HF_TOKEN"]},"primaryEnv":"HF_TOKEN"}}
    ---

    # Hugging Face Image Generation

    Generate images using the Hugging Face Inference API. Free tier available.

    ## Usage

    ```bash
    ${huggingface-generate}/bin/huggingface-generate --prompt "your description" --filename "output.png" [--model MODEL] [--width N] [--height N] [--negative-prompt TEXT] [--seed N]
    ```

    **Important:** Always run from the user's current working directory.

    ## Models

    - **flux-schnell** (default) — FLUX.1 Schnell, fast and high quality
    - **flux-dev** — FLUX.1 Dev, higher quality, slower
    - **sdxl** — Stable Diffusion XL
    - **sd3** — Stable Diffusion 3 Medium

    ## Options

    - `--prompt` (required) — Image description
    - `--filename` (required) — Output filename (PNG)
    - `--model` — Model choice (default: flux-schnell)
    - `--width` — Width in pixels (default: 1024)
    - `--height` — Height in pixels (default: 1024)
    - `--negative-prompt` — What to avoid
    - `--seed` — Seed for reproducibility

    ## Filename Format

    `{timestamp}-{descriptive-name}.png` (e.g., `2026-02-18-03-00-00-sunset.png`)

    ## Notes

    - Free tier is rate-limited but generous for casual use
    - Models may need ~30s cold start on first request (auto-retried)
  '';
in {
  config = mkIf cfg.enable {
    # Symlink skill dirs into ~/.openclaw/skills/
    systemd.tmpfiles.rules = let
      home = "/home/${cfg.user}";
    in [
      "d ${home}/.openclaw/skills 0755 ${cfg.user} users -"
      "L+ ${home}/.openclaw/skills/pollinations - - - - ${pollinations-skill}/pollinations"
      "L+ ${home}/.openclaw/skills/huggingface-image - - - - ${huggingface-skill}/huggingface-image"
    ];
  };
}
