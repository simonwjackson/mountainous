# Aka local-LLM benchmark: Qwen3.6-27B

**Qwen3.6-27B IQ4_XS runs fully on Aka's RX 7900 XT (20 GB) at 34–36 tok/s
when the context is empty, and up to 128k tokens of context fits.** ROCm
reads prompts 6–32% faster than Vulkan in every test. Vulkan generates
faster up to 64k tokens of context (36.0 vs 34.4 empty, 28.9 vs 22.1 at 64k).
ROCm generates faster only at 128k (16.0 vs 7.2).

Measured on 2026-10-09 with `llama-bench` from nixpkgs `4975466d`
(llama.cpp 0.4.1, build 10964, commit `b29c606`). Settings: all layers on the
GPU, flash attention on, 8-bit (`q8_0`) K and V cache. Black & White 2 and its
Proton sandbox were stopped first. The sway desktop was still running on the
7900 XT (95 MiB VRAM before the test).

## Results (tokens per second)

| Test | Vulkan | ROCm |
| --- | ---: | ---: |
| Prompt 512, empty context | 766 | 863 |
| Prompt 4096, empty context | 745 | 791 |
| Cold 32k prompt (one 32768-token read) | 592 (55.4 s) | 662 (49.5 s) |
| Prompt 512 at 32k depth | 480 | 595 |
| Prompt 512 at 64k depth | 349 | 463 |
| Prompt 512 at 128k depth | 221 | 291 |
| Generate 128, empty context | 36.0 | 34.4 |
| Generate 128 at 32k depth | 31.8 | 26.9 |
| Generate 128 at 64k depth | 28.9 | 22.1 |
| Generate 32 at 128k depth | 7.2 | 16.0 |

Repetitions: 3 per test with empty context, 2 at 32k/64k depth, 1 for the
cold 32k prompt and the 128k depth test. The 128k results are single samples.

## GPU sensors during the runs

| Backend | VRAM peak | Edge peak | Junction peak | Memory peak | Power avg |
| --- | ---: | ---: | ---: | ---: | ---: |
| Vulkan | 19703 MiB | 84°C | 102°C | 98°C | 257 W |
| ROCm | 19825 MiB | 84°C | 102°C | 100°C | 258 W |

VRAM total is 20464 MiB. At 128k context, less than 0.7 GB stays free.
Samples are every 2 s from the amdgpu hwmon files. The card's power cap is
265 W. The power peaks (368 W Vulkan, 326 W ROCm) are single sample readings
and are not proof that the card went over the cap for a sustained time.

## Reproduce

```sh
nix build path:docs/hardware/aka-llm-benchmark-2026-10-09#model \
          path:docs/hardware/aka-llm-benchmark-2026-10-09#rocm
./result-1/bin/aka-llm-bench-rocm ./out d0 cold depth fit
```

The model is a fixed-output `fetchurl` of
`unsloth/Qwen3.6-27B-GGUF` commit `82d411ac`, file `Qwen3.6-27B-IQ4_XS.gguf`,
SHA-256 `8a3365759dc1b33b52c4e7d91d5a67d5ee1418e8408aa54196f04a98da53e5dc`.
Raw `llama-bench` JSONL, logs, and sensor CSVs are in
`docs/hardware/aka-llm-benchmark-2026-10-09/out/`.

## Limits

- This measures speed, not coding quality.
- MTP (multi-token prediction) was not tested. The unsloth MTP GGUF is a
  separate file.
- The vision projector (mmproj) was not loaded.
- `llama-bench` does not measure llama-server prompt-cache reuse between
  agent turns.
