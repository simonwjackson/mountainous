---
title: feat: Add aka Qwen32 llama service
type: feat
status: active
date: 2026-05-25
origin: docs/brainstorms/2026-05-25-aka-qwen32-llama-service-requirements.md
---

# feat: Add aka Qwen32 llama service

## Summary

Implement the Qwen2.5-Coder 32B server as a host-local `aka` NixOS systemd service: reuse existing host service patterns, use a Vulkan-enabled llama.cpp package, keep the service manually started, and rely on Tailscale-trusted firewall posture rather than broad LAN exposure.

---

## Problem Frame

The origin requirements define a durable replacement for ad hoc local helper scripts that currently start the `aka`-hosted llama.cpp server for Pi. The implementation needs to make that runtime reproducible through the `aka` host configuration while preserving the tested model choices and on-demand resource profile.

---

## Requirements

- R1. `aka` has an official declared service for running Qwen2.5-Coder 32B through llama.cpp.
- R2. The service is available for manual start but does not start automatically at boot.
- R3. The service exposes an OpenAI-compatible API compatible with the existing Pi model configuration.
- R4. The default model is Q4_K_S, with Q3_K_M available as the fallback.
- R5. The service uses AMD/Vulkan GPU acceleration on `aka`.
- R6. Stopping the service releases the llama.cpp process and GPU memory.
- R7. Network exposure is limited to trusted access, preferably Tailscale.
- R8. The service reuses the existing user-owned llama.cpp/Hugging Face cache when practical.
- R9. The configuration makes clear that Q3 and Q4 variants should not run simultaneously.
- R10. Start, stop, and status use ordinary system service operations.

**Origin actors:** A1 (Pi user), A2 (Pi harness), A3 (`aka`)
**Origin flows:** F1 (Start model service for Pi use), F2 (Stop model service after use)
**Origin acceptance examples:** AE1 (service start and Pi prompt succeeds), AE2 (not running at boot and stops cleanly), AE3 (trusted-only exposure), AE4 (cache reuse)

---

## Scope Boundaries

- Do not create a reusable multi-host local-LLM feature module in this iteration.
- Do not change Pi's provider/model registry configuration.
- Do not benchmark models or introduce additional variants.
- Do not run multiple Qwen2.5-Coder 32B variants concurrently.
- Do not expose the service publicly or open the port on broad LAN interfaces.
- Do not fix unrelated Korri option/input drift except as a verification blocker note if it prevents `aka` evaluation or build.

---

## Context & Research

### Relevant Code and Patterns

- `hosts/aka/default.nix` already owns host-local runtime services for `aka`, including Sway startup, Sunshine, Korri server configuration, AMD graphics enablement, and host-specific package additions.
- `hosts/aka/hardware.nix` enables the AMD GPU driver stack through `amdgpu` kernel modules and `services.xserver.videoDrivers = ["amdgpu"]`.
- `presets/core/nixos.nix` enables the firewall by default and marks `tailscale0` as trusted, which allows a service to remain reachable over Tailscale without adding a broad `allowedTCPPorts` rule.
- `features/openclaw-gateway/nixos.nix` is a useful pattern for a system service that runs as `simonwjackson`, sets `HOME`, uses a generated shell script, and exposes a long-running service through systemd.
- `features/tsnet-proxy/nixos.nix` is a useful pattern for hardening network services when they run as dedicated system users; this plan intentionally does not copy its dedicated-user pattern because cache reuse is a requirement.
- `flake.nix` automatically imports feature modules and host configs; host-specific work can land in `hosts/aka/default.nix` without adding new import wiring.
- `docs/nix-commands.md` defines the direct Nix build, test, and switch commands.
- Nixpkgs provides `pkgs.llama-cpp`; the package supports a `vulkanSupport` override and installs the server binary needed for OpenAI-compatible serving.

### Institutional Learnings

- No `docs/solutions/` directory or matching institutional-learning documents exist in this repository snapshot. Planning therefore relies on the origin requirements, host configuration patterns, and local NixOS module conventions.

### External References

- No external web research was used. The relevant behavior is determined by existing local smoke tests from the handoff plus the current nixpkgs `llama-cpp` package definition.

---

## Key Technical Decisions

- Keep the service host-local in `hosts/aka/default.nix`: The requirement is specific to `aka`, and a reusable feature module would add carrying cost before there is a second host or stable abstraction.
- Use `pkgs.llama-cpp` with Vulkan support enabled: The default nixpkgs package exists, and its package definition exposes the needed backend switch without vendoring llama.cpp or adding a new flake input.
- Run the system service as `simonwjackson`: This preserves the tested user cache location and avoids a separate service-account model download.
- Use one service with one active model at a time: A single service preserves the no-concurrent-Q3/Q4 requirement and avoids accidental VRAM contention.
- Bind for Tailscale reachability but do not open a broad firewall port: The core preset already trusts `tailscale0`; avoiding `allowedTCPPorts` keeps LAN/public exposure closed while allowing MagicDNS/Tailscale clients to reach the service.
- Treat fallback model selection as an operator-controlled service setting, not a second always-declared running service: The fallback must be available without creating two easy-to-start concurrent units.

---

## Open Questions

### Resolved During Planning

- Should this be a reusable feature or host-local config?: Host-local config, because the origin scope is `aka`-specific and explicitly rejects a reusable multi-host framework.
- Should trusted access bind to a dynamic Tailscale IP directly?: Prefer firewall-based trusted exposure over hard-coding a Tailscale IP. Binding to a dynamic address can fail when Tailscale is not ready or the address changes; relying on the existing trusted `tailscale0` firewall posture is simpler and aligns with current repo defaults.
- Should Q3 and Q4 be separate runnable services?: No. Use one active service path with a default model and an override/fallback mechanism to avoid concurrent VRAM contention.

### Deferred to Implementation

- Exact fallback switch shape: The implementer may choose a Nix constant, systemd environment override, or small operator-facing override file as long as there is only one active service and Q4 remains the default.
- Exact service hardening set: The implementer should add low-risk systemd hardening, but must not break access to the user cache or GPU devices.
- Exact health endpoint used for smoke testing: Use a llama.cpp server endpoint that is present in the packaged version after implementation.

---

## Implementation Units

### U1. Add the Vulkan llama.cpp service definition

**Goal:** Define the `aka` on-demand systemd service using a Vulkan-enabled llama.cpp package and the smoke-tested model defaults.

**Requirements:** R1, R2, R3, R4, R5, R9, R10; supports F1 and AE1

**Dependencies:** None

**Files:**
- Modify: `hosts/aka/default.nix`
- Test: no dedicated test file; verify this host-local NixOS configuration through evaluation/build and on-host service smoke tests.

**Approach:**
- Add local `let` bindings near the existing `aka` service constants for the service name, port, context size, default Q4_K_S model, fallback Q3_K_M model, and Vulkan-enabled llama.cpp package.
- Define a generated launcher script that starts the llama.cpp server with the OpenAI-compatible server binary, the default model, Vulkan device selection, GPU layer offload, context size, host, and port.
- Keep the fallback model visible in the config through named constants and comments or an operator override mechanism, but do not declare a second concurrent service unit.
- Do not add `wantedBy = ["multi-user.target"]`; the unit should exist for manual `systemctl start` only.

**Patterns to follow:**
- Host-local constants and generated shell scripts in `hosts/aka/default.nix`.
- Long-running system service shape in `features/openclaw-gateway/nixos.nix`.

**Test scenarios:**
- Happy path: Given the evaluated `aka` configuration, the service definition exists and points at the Vulkan-enabled llama.cpp server package.
- Happy path: Given the evaluated service definition, the default model is Q4_K_S and the fallback Q3_K_M is represented without creating a second runnable service.
- Edge case: Given the evaluated service definition, the service has no boot target install and therefore is not automatically started at boot.
- Integration: Covers AE1. Given the host is switched and the service is started manually, Pi can send a trivial OpenAI-compatible prompt to the `aka` endpoint and receive a successful response.

**Verification:**
- The `aka` NixOS configuration evaluates with the service present.
- The service is startable manually through normal systemd operations and is not enabled at boot.
- The effective server command uses the Q4_K_S model by default and a Vulkan-enabled llama.cpp build.

---

### U2. Preserve cache, GPU access, and trusted-network exposure

**Goal:** Ensure the service runs with the right user environment, can access AMD/Vulkan devices, and remains reachable over Tailscale without broad LAN exposure.

**Requirements:** R5, R6, R7, R8, R10; supports F1, F2, AE2, AE3, AE4

**Dependencies:** U1

**Files:**
- Modify: `hosts/aka/default.nix`
- Test: no dedicated test file; verify this host-local NixOS configuration through evaluation/build and on-host service smoke tests.

**Approach:**
- Run the service as `simonwjackson` with `HOME` and cache-related environment pointing at the user's home/cache so `-hf` model downloads reuse the already-tested location.
- Ensure the service user has the required GPU device group access for render/video devices if the current user declaration does not already provide it.
- Add service ordering that makes network/Tailscale availability likely before manual start, without converting the service into a boot-starting daemon.
- Do not add the llama server port to `networking.firewall.allowedTCPPorts`; rely on the existing trusted `tailscale0` posture for Tailscale clients and closed LAN access.
- Use restart behavior that helps if the server crashes during an intentional session but does not undermine manual stop semantics.

**Patterns to follow:**
- User-owned service environment in `features/openclaw-gateway/nixos.nix`.
- Trusted-interface firewall default in `presets/core/nixos.nix`.
- AMD graphics enablement already present in `hosts/aka/default.nix` and `hosts/aka/hardware.nix`.

**Test scenarios:**
- Happy path: Given the service starts as `simonwjackson`, model cache resolution points at the user's cache rather than a system account cache.
- Happy path: Covers AE2. Given `aka` has just booted, the service is inactive; when manually stopped after use, the llama.cpp process exits.
- Edge case: Covers AE3. Given the port is not added to broad firewall allowed ports, non-Tailscale LAN/public clients are not granted firewall access by this change.
- Error path: Given GPU device permissions are insufficient on first implementation attempt, the fix is to adjust user/group/device access in the NixOS config rather than falling back to CPU serving.

**Verification:**
- The evaluated config shows no new broad firewall port opening for the llama server.
- The service process runs as `simonwjackson` and uses the intended home/cache environment.
- Starting and stopping the service changes the process state as expected and releases the server process.

---

### U3. Add operator documentation and verification notes

**Goal:** Document how to operate and verify the official service so future sessions do not depend on the original ad hoc helper scripts or chat handoff.

**Requirements:** R3, R4, R6, R9, R10; supports F1, F2, AE1, AE2

**Dependencies:** U1, U2

**Files:**
- Create: `docs/runbooks/aka-qwen32-llama-service.md`
- Test: no dedicated test file; verify by checking the runbook against the implemented service name, model names, and endpoint.

**Approach:**
- Document the service purpose, default model, fallback model, endpoint intended for Pi, and start/stop/status workflow.
- Include the important operational warning that Q3 and Q4 should not be run concurrently.
- Include a concise verification checklist covering service start, health/API smoke test, Pi prompt smoke test, and service stop.
- Keep the runbook focused on operating this declared service; do not document Pi provider setup unless it is needed as a reference to the existing client expectation.

**Patterns to follow:**
- Existing concise operational docs under `docs/runbooks/`.
- Origin requirements in `docs/brainstorms/2026-05-25-aka-qwen32-llama-service-requirements.md` for scope boundaries and model names.

**Test scenarios:**
- Happy path: Given a future operator reads the runbook, they can identify the default model, endpoint, and start/stop/status operations without consulting chat history.
- Edge case: Given the operator wants to use the fallback model, the runbook makes clear that fallback selection must not result in simultaneous Q3 and Q4 services.
- Integration: Covers AE1 and AE2. Given the service has been deployed, the runbook's verification checklist proves manual start, Pi prompt success, and manual stop.

**Verification:**
- The runbook references repo/current service names and model names consistently with the NixOS config.
- The runbook does not introduce additional scope such as benchmarking, Pi registry rewrites, or multi-host generalization.

---

## System-Wide Impact

- **Interaction graph:** The change affects `aka`'s systemd unit graph, user/group membership, firewall posture, and Pi's ability to reach the existing OpenAI-compatible endpoint over Tailscale/MagicDNS.
- **Error propagation:** Service start failures should surface through systemd status/journal output; Pi failures should remain ordinary API connection/model errors rather than hidden helper-script failures.
- **State lifecycle risks:** Model cache state remains in the user's home cache; stopping the service should remove the active server process but not delete cached model files.
- **API surface parity:** The OpenAI-compatible API surface used by Pi must remain compatible with the provider/model entries created outside this repo.
- **Integration coverage:** Repo evaluation/build proves the declared config; only an on-host smoke test can prove GPU device access, model cache reuse, and Pi connectivity.
- **Unchanged invariants:** Existing Korri, Sunshine, Sway, and core Tailscale behavior on `aka` should remain unchanged except for any user group additions needed for GPU access.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| The current `aka` flake evaluation may already be blocked by unrelated Korri option drift. | Treat this as a verification blocker separate from the Qwen service; do not fold a Korri migration into this plan unless required to evaluate the host. |
| The default `pkgs.llama-cpp` build may not include Vulkan support unless overridden. | Use the nixpkgs `vulkanSupport` override explicitly and verify the effective package/server can start with the Vulkan device option. |
| Running as `simonwjackson` may still lack render-device access in a system service context. | Ensure group/device access is declared in NixOS and verify with an on-host service start. |
| Binding to all interfaces with no broad firewall opening relies on the host firewall working as intended. | Preserve `tailscale0` as trusted and avoid adding `allowedTCPPorts`; verify from a trusted Tailscale client and avoid LAN exposure changes. |
| A fallback mechanism could accidentally permit Q3 and Q4 to run at once. | Keep one service unit as the active runtime and document/encode fallback as a model selection, not a second parallel daemon. |

---

## Documentation / Operational Notes

- Add `docs/runbooks/aka-qwen32-llama-service.md` as the durable operator reference.
- Use direct NixOS validation with `nixos-rebuild build --flake .#aka` or `sudo nixos-rebuild test --flake .#aka`.
- After deploy, verify the real runtime on `aka` with a service start, a server health/API request, a Pi prompt smoke test, and a service stop.

---

## Sources & References

- **Origin document:** [docs/brainstorms/2026-05-25-aka-qwen32-llama-service-requirements.md](../brainstorms/2026-05-25-aka-qwen32-llama-service-requirements.md)
- Related code: `hosts/aka/default.nix`
- Related code: `hosts/aka/hardware.nix`
- Related code: `presets/core/nixos.nix`
- Related code: `features/openclaw-gateway/nixos.nix`
- Related code: `features/tsnet-proxy/nixos.nix`
- Related documentation: `docs/nix-commands.md`
