---
date: 2026-03-07
topic: headless-nzb-downloader-mvp
---

# Headless NZB Downloader MVP

## What We're Building
A headless Usenet binary downloader MVP inspired by NZBGet’s daemon mode, but scoped down to the minimum needed for reliable unattended operation. The product should ingest NZB files, manage a queue, download articles from configured NNTP servers, decode and assemble files, persist enough state to survive restarts, and expose machine-friendly control through a simple API/CLI.

The MVP is explicitly not a full NZBGet clone. It should avoid a built-in web UI, legacy RPC compatibility, feed readers, script/plugin systems, and advanced scheduler/dupe features. The emphasis is on a boring, restart-safe daemon that can be configured declaratively and inspected with plain-text state.

## Why This Approach
Three broad options were considered. First, keep using upstream NZBGet, which is mature and efficient but remains partly web-configured and does not align with the goal of plain-text, fully declarative state. Second, build a full replacement with fine-grained internal persistence for every segment, which would likely recreate much of NZBGet’s complexity too early. Third, build a smaller headless daemon in TypeScript with Bun-compatible, Node-style APIs and plain-text persistence. The third option is the best MVP fit.

The recommended design uses `@proseql/core`/`@proseql/node` for the control plane only: queue metadata, file progress, history, and append-only events. Large immutable NZB manifests and hot-path segment details stay outside the main mutable collections. This keeps the system inspectable and text-backed without forcing a text database to absorb high-churn per-segment updates.

Repository patterns to reuse:
- `nix/features/trove/usenet/nixos.nix` already models NZBGet declaratively with typed settings and secret injection.
- `packages/scripts/tasks-query.sh` shows Bun is already an accepted runtime in this repo and that ProseQL is already part of the author’s toolchain.

## Key Decisions
- **Headless-first scope**: the MVP is a daemon + API/CLI, not a web application.
- **TypeScript implementation**: build in TS with Bun-compatible, Node-style APIs to maximize development speed while preserving the option to run under Node if needed.
- **Streaming over caching**: keep article buffering bounded and disk-first to reduce Bun/GC memory pressure.
- **ProseQL for control-plane state only**: store jobs, files, history, and events in plain-text collections.
- **No per-segment mutable ProseQL entities**: avoid modeling every segment as a hot mutable record, since that would create unnecessary churn and memory overhead.
- **Immutable manifests as sidecar files**: store parsed NZB structure separately per job so restart recovery remains inspectable without bloating mutable collections.
- **Append-only event log**: use JSONL-style append-only persistence for operational history, retries, and transitions.
- **External post-processing tools**: shell out to `par2cmdline`, `7z`, and/or `unrar` for repair/unpack instead of implementing those in-process.

## Resolved Questions
- **Can Bun work for this MVP?** Yes, provided the downloader stays streaming, bounded, and disk-first.
- **Should plain-text persistence replace a binary DB?** Yes, but only for coarse-grained state; hot-path segment state should remain compact and not be modeled as constantly rewritten collection rows.
- **Is ProseQL a fit?** Yes, as the state store for jobs/files/events, not as the primary storage layer for every segment mutation.

## Open Questions
None at this stage.

## Next Steps
→ `/forgerie:spec` for implementation details, including exact schema design, disk layout, restart recovery, and API surface.
