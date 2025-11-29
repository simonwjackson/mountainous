# Declarative Mythomax Setup for Ollama on NixOS

## Goal
Set up Mythomax 13B (best AI Dungeon clone model) declaratively on aka.

## Problem
Ollama's `loadModels` only works with library models. Mythomax requires downloading a GGUF and importing manually.

## Solution: Systemd Service

Add to `aka/default.nix`:

```nix
# Mythomax model for AI Dungeon-style text adventures
systemd.services.ollama-mythomax = {
  description = "Download and import Mythomax model for Ollama";
  after = [ "ollama.service" ];
  wants = [ "ollama.service" ];
  wantedBy = [ "multi-user.target" ];

  path = [ pkgs.curl pkgs.ollama ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    StateDirectory = "ollama-models";
  };

  script = ''
    MODEL_DIR="/var/lib/ollama-models"
    GGUF="$MODEL_DIR/mythomax-l2-13b.Q4_K_M.gguf"
    MODELFILE="$MODEL_DIR/Modelfile.mythomax"

    # Skip if model already exists
    if ollama list | grep -q "mythomax"; then
      echo "Mythomax already installed"
      exit 0
    fi

    # Download GGUF if not present
    if [ ! -f "$GGUF" ]; then
      echo "Downloading Mythomax GGUF (~8GB)..."
      curl -L -o "$GGUF" \
        "https://huggingface.co/TheBloke/MythoMax-L2-13B-GGUF/resolve/main/mythomax-l2-13b.Q4_K_M.gguf"
    fi

    # Create Modelfile
    cat > "$MODELFILE" << 'EOF'
    FROM /var/lib/ollama-models/mythomax-l2-13b.Q4_K_M.gguf
    PARAMETER temperature 0.8
    PARAMETER top_p 0.95
    PARAMETER repeat_penalty 1.1
    SYSTEM You are a creative storyteller running an interactive text adventure game.
    EOF

    # Import to Ollama
    cd "$MODEL_DIR"
    ollama create mythomax -f "$MODELFILE"
  '';
};
```

## Alternative: Use hermes3 (easier)

If Mythomax is too complex, `hermes3` is in the Ollama library and decent for storytelling:

```nix
services.ollama = {
  enable = true;
  acceleration = "rocm";
  loadModels = ["nomic-embed-text" "hermes3"];
};
```

## Frontend Options

- **SillyTavern**: Best UI, run via Docker
- **KoboldAI Lite**: https://lite.koboldai.net (connect to `http://aka:11434`)

## Models Comparison

| Model | Library? | AI Dungeon Feel | Size |
|-------|----------|-----------------|------|
| mythomax | No (GGUF) | ★★★★★ | 8GB |
| hermes3 | Yes | ★★★★☆ | 5GB |
| nous-hermes2 | Yes | ★★★★☆ | 4GB |

## Next Steps

1. Test the systemd service approach
2. Consider making a reusable NixOS module for custom GGUF models
3. Set up SillyTavern as a companion service
