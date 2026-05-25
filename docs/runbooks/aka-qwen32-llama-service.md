# Aka Qwen32 llama.cpp service

`aka-llama-qwen32.service` runs Qwen2.5-Coder 32B through llama.cpp on `aka` for Pi's OpenAI-compatible `aka-llama` provider.

## Defaults

- Service: `aka-llama-qwen32.service`
- Endpoint: `http://aka:18080/v1`
- Default model: `bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_S`
- Fallback model: `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:q3_k_m`
- Context size: `32768`
- GPU backend: Vulkan (`Vulkan0`, all GPU layers)

The service is intentionally on-demand. It is declared in NixOS but not enabled at boot, so it only consumes GPU memory while explicitly running.

## Operate

Start the server on `aka`:

```bash
sudo systemctl start aka-llama-qwen32
```

Check status:

```bash
sudo systemctl status aka-llama-qwen32
```

Stop the server when done:

```bash
sudo systemctl stop aka-llama-qwen32
```

## Fallback model

Use only one Qwen32 variant at a time. Do not start a second llama.cpp server for Q3 while Q4 is running; both variants compete for the same GPU memory.

The declared service defaults to Q4_K_S. To use the fallback Q3_K_M model for a session, override `AKA_LLAMA_QWEN32_MODEL` for the service and restart it. Keep the override temporary unless Q4_K_S is consistently too tight for `aka`.

## Verify

After switching `aka` to the new configuration:

1. Start the service.
2. Confirm the server is listening from a trusted Tailscale client:

   ```bash
   curl http://aka:18080/health
   ```

3. Confirm Pi can reach the OpenAI-compatible endpoint with the configured model:

   ```bash
   pi --model aka-llama/qwen2.5-coder-32b-q4-k-s -p --no-tools --thinking off --no-session 'Reply with exactly: OK'
   ```

4. Stop the service.
5. Confirm the service is inactive and the model process is gone.

If the server starts by redownloading a model into an unexpected account cache, check that the unit is running as `simonwjackson` and that `HOME`, `XDG_CACHE_HOME`, and `HF_HOME` point at the user cache.
