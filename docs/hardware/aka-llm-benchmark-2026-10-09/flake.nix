{
  description = "Aka local-LLM benchmark: Qwen3.6-27B IQ4_XS on llama.cpp (Vulkan and ROCm)";

  # Same nixpkgs revision as the mountainous flake.lock on 2026-10-09.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Fixed-output download. The hash is the Hugging Face LFS SHA-256 for
      # this file at repository commit 82d411ac.
      model = pkgs.fetchurl {
        name = "Qwen3.6-27B-IQ4_XS.gguf";
        url = "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/82d411acf4a06cfb8d9b073a5211bf410bfc29bf/Qwen3.6-27B-IQ4_XS.gguf";
        sha256 = "8a3365759dc1b33b52c4e7d91d5a67d5ee1418e8408aa54196f04a98da53e5dc";
      };

      mkBench =
        backend: llama: device:
        pkgs.writeShellApplication {
          name = "aka-llm-bench-${backend}";
          runtimeInputs = [
            llama
            pkgs.coreutils
            pkgs.gnugrep
          ];
          text = ''
            # Usage: aka-llm-bench-${backend} OUTDIR [stage...]
            # Stages: d0 cold depth fit. Default: d0 cold depth.
            outdir="$1"; shift
            stages=("$@")
            if [ ''${#stages[@]} -eq 0 ]; then stages=(d0 cold depth); fi
            mkdir -p "$outdir"

            # GPU sensor sampler for the RX 7900 XT (PCI device 0x744c).
            gpu=""
            for d in /sys/class/drm/card*/device; do
              if [ "$(cat "$d/device")" = "0x744c" ]; then gpu="$d"; fi
            done
            hws=("$gpu"/hwmon/hwmon*)
            hw="''${hws[0]}"
            (
              echo "epoch,edge_mC,junction_mC,mem_mC,power_uW,vram_used_B"
              while :; do
                printf '%s,%s,%s,%s,%s,%s\n' "$(date +%s.%N)" \
                  "$(cat "$hw/temp1_input")" "$(cat "$hw/temp2_input")" "$(cat "$hw/temp3_input")" \
                  "$(cat "$hw/power1_average" 2>/dev/null || cat "$hw/power1_input")" \
                  "$(cat "$gpu/mem_info_vram_used")"
                sleep 2
              done
            ) > "$outdir/gpu-${backend}.csv" &
            sampler=$!
            trap 'kill "$sampler"' EXIT

            # 8-bit KV cache needs flash attention. Pin the discrete GPU so
            # llama.cpp does not split layers onto the iGPU.
            common=(-m ${model} -dev ${device} -ngl 99 -fa on -ctk q8_0 -ctv q8_0 -o jsonl)

            run() {
              local name="$1"; shift
              echo "== ${backend} $name: $*" >&2
              llama-bench "''${common[@]}" "$@" \
                > "$outdir/${backend}-$name.jsonl" 2> "$outdir/${backend}-$name.log"
              cat "$outdir/${backend}-$name.jsonl"
            }

            for s in "''${stages[@]}"; do
              case "$s" in
                d0)    run d0    -p 512,4096 -n 128 -d 0 -r 3 ;;
                cold)  run cold  -p 32768 -n 0 -r 1 ;;           # cold 32k agent prompt
                depth) run depth -p 512 -n 128 -d 32768,65536 -r 2 ;;
                fit)   run fit   -p 512 -n 32 -d 131072 -r 1 ;;  # does 128k context fit?
                *) echo "unknown stage $s" >&2; exit 2 ;;
              esac
            done
          '';
        };
    in
    {
      packages.${system} = {
        inherit model;
        vulkan = mkBench "vulkan" pkgs.llama-cpp-vulkan "Vulkan0";
        rocm = mkBench "rocm" pkgs.llama-cpp-rocm "ROCm0";
      };
    };
}
