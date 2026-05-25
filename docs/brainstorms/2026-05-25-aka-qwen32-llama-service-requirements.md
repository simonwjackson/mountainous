---
date: 2026-05-25
topic: aka-qwen32-llama-service
---

# Aka Qwen32 Llama Service Requirements

## Summary

Define an official `aka` NixOS setup for running Qwen2.5-Coder 32B as an on-demand llama.cpp server for Pi, with safe network exposure and resource defaults that keep the model available without permanently consuming GPU memory.

---

## Problem Frame

Qwen2.5-Coder 32B has already been smoke-tested successfully on `aka` through llama.cpp with Vulkan acceleration. Pi can use the resulting OpenAI-compatible API when the ad hoc server is running, but the current setup depends on manually maintained helper scripts outside the repo and local knowledge from the previous session.

The pain is operational drift: the working model/server shape is valuable enough to reuse, but not durable enough to survive rebuilds, handoffs, or future maintenance unless it becomes part of the host's declared system configuration.

---

## Actors

- A1. Pi user: Starts or stops the local model server when they want to use the `aka`-hosted coding model.
- A2. Pi harness: Connects to an OpenAI-compatible API exposed by `aka`.
- A3. `aka`: Provides the GPU-backed llama.cpp runtime and model cache.

---

## Key Flows

- F1. Start model service for Pi use
  - **Trigger:** The Pi user wants to run Pi against the `aka`-hosted Qwen2.5-Coder 32B model.
  - **Actors:** A1, A2, A3
  - **Steps:** The user starts the declared service on `aka`; the service loads the selected model using GPU acceleration; Pi connects to the OpenAI-compatible API; the user verifies a simple prompt succeeds.
  - **Outcome:** Pi can use the `aka` model without relying on ad hoc shell scripts as the source of truth.
  - **Covered by:** R1, R2, R3, R4, R5

- F2. Stop model service after use
  - **Trigger:** The user is done with local inference or wants GPU memory back for other workloads.
  - **Actors:** A1, A3
  - **Steps:** The user stops the declared service; the llama.cpp process exits; GPU memory is released.
  - **Outcome:** `aka` returns to its normal idle/resource state without leaving the model server running indefinitely.
  - **Covered by:** R1, R6

---

## Requirements

**Service behavior**
- R1. `aka` has an official declared service for running Qwen2.5-Coder 32B through llama.cpp.
- R2. The service is on-demand: it must be available to start manually, but must not start automatically at boot by default.
- R3. The service exposes an OpenAI-compatible API that the existing Pi model configuration can target.
- R4. The default model is the smoke-tested Q4_K_S variant; the smoke-tested Q3_K_M variant remains available as a fallback path.
- R5. The service uses GPU acceleration suitable for `aka`'s AMD/Vulkan setup.
- R6. Stopping the service releases the model process and avoids keeping GPU memory occupied when not in use.

**Safety and operations**
- R7. Network exposure is limited to trusted access, preferably Tailscale, rather than broad public LAN or internet exposure.
- R8. The service reuses the existing user-owned llama.cpp/Hugging Face cache when practical so models are not redownloaded under an unexpected account.
- R9. The configuration makes it clear that Q3 and Q4 variants should not run simultaneously on `aka`.
- R10. The operator-facing commands are ordinary system service operations, so starting, stopping, and checking status are discoverable through standard NixOS/systemd workflows.

---

## Acceptance Examples

- AE1. **Covers R1, R2, R3.** Given `aka` has been rebuilt with the new configuration, when the user starts the declared service and sends Pi a trivial prompt through the configured model, Pi receives a successful response from the `aka`-hosted API.
- AE2. **Covers R2, R6.** Given `aka` has just booted, the Qwen2.5-Coder 32B service is not running until the user starts it; after the user stops it, the model process is no longer active.
- AE3. **Covers R7.** Given another device outside the trusted network attempts to reach the service, it is not exposed as a public internet or broad LAN service.
- AE4. **Covers R8.** Given the model has already been downloaded in the user cache, starting the service does not redownload the same model into an unrelated service account cache.

---

## Success Criteria

- Pi can reliably use the `aka`-hosted Qwen2.5-Coder 32B model after a NixOS rebuild without relying on undocumented local scripts.
- `aka` does not spend GPU memory on the model unless the user explicitly starts the service.
- The service is reachable from trusted devices and not accidentally exposed more broadly.
- A downstream planner can implement the service without re-deciding the model choice, startup policy, network posture, or cache ownership goal.

---

## Scope Boundaries

- Do not make the inference service always-on by default.
- Do not expose the service publicly on the internet.
- Do not run multiple Qwen2.5-Coder 32B variants simultaneously.
- Do not rework Pi's model registry or provider setup as part of this change.
- Do not benchmark or select new models beyond the two variants already smoke-tested.
- Do not generalize this into a reusable multi-host local-LLM framework in this iteration.

---

## Key Decisions

- On-demand service over boot service: preserves the working workflow while avoiding constant GPU memory consumption.
- Q4_K_S default with Q3_K_M fallback: uses the higher-quality smoke-tested variant by default while retaining a smaller fallback if resources are tight.
- Trusted-network exposure only: makes the service convenient for Pi without treating a local model server as a public service.
- User cache reuse: avoids surprise redownloads and keeps the declared service aligned with the already-tested runtime state.

---

## Dependencies / Assumptions

- `aka` continues to have working AMD/Vulkan acceleration for llama.cpp.
- The existing Pi provider/model entries remain pointed at an `aka` OpenAI-compatible API.
- The current user cache contains or can contain the selected GGUF model variants.
- Planning may choose the exact binding strategy, service user, environment, and fallback-selection mechanism as long as the requirements above are preserved.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R7][Technical] Should the service bind directly to `aka`'s Tailscale address, bind locally with a tunnel, or use another trusted-network-only mechanism?
- [Affects R4, R9][Technical] Should fallback model selection be a separate service, an override, or an environment/configuration switch?
