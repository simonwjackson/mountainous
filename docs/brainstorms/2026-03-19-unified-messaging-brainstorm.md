---
date: 2026-03-19
topic: unified-messaging
---

# Unified Messaging

## What We're Building

A self-hosted Matrix homeserver (Synapse) on yari with mautrix-signal bridge as an MVP. This gives a single inbox for Signal messages alongside any future bridges, accessed via an open-source Matrix client (Element or SchildiChat) on Android and NixOS desktops.

## Why This Approach

Three approaches were considered:

1. **Beeper (hosted SaaS)** — Best UI, built-in contact unification, but locked to Beeper's infrastructure. Cannot connect to a self-hosted homeserver. No Google Voice support.
2. **Self-hosted Matrix + open-source client** — Full control, NixOS-native modules in nixpkgs, extensible with any bridge (including future Google Voice). No contact unification.
3. **Beeper + self-hosted bridges** — Beeper's bridge-manager only works with Beeper's hosted server, not a self-hosted Synapse.

Chose **Option 2** because:
- Contact unification (Beeper's advantage) is locked behind a proprietary client that can't connect to a self-hosted server
- NixOS has first-class modules for Synapse, mautrix-signal, and mautrix-whatsapp
- Self-hosted allows adding Google Voice bridge (mautrix/gvoice) later
- No vendor dependency — fully open source stack
- Fits existing NixOS infrastructure patterns

## Key Decisions

- **Homeserver**: Synapse (most mature, best bridge compatibility, NixOS module exists)
- **Database**: SQLite for MVP simplicity — migrate to PostgreSQL if performance requires
- **Bridge**: mautrix-signal first (most stable bridge, uses official linked-device protocol)
- **Access**: Tailscale only — no public federation, no nginx/TLS needed for MVP
- **Client**: Element or SchildiChat on Android + desktop (open-source Matrix clients)
- **Insecure package**: olm-3.2.16 permitted (deprecated crypto lib still required by bridges until vodozemac migration)
- **Contact unification**: Deferred — not available in any open-source Matrix client today

## Trade-offs Accepted

- No contact unification (the #1 desired feature) — this is a known gap
- No voice/video calls through the bridge — must use native Signal app for calls
- Signal bridge links as secondary device — phone must remain active Signal device
- Element UI is functional but not as polished as Beeper

## Future Expansion Path

1. **WhatsApp bridge** — `services.mautrix-whatsapp` NixOS module ready in nixpkgs
2. **Google Voice bridge** — `mautrix/gvoice` exists (SMS only, no calls) but needs custom Nix packaging
3. **VoIP** — Port Google Voice number to SIP provider, use matrix-sip-bridge for calls
4. **PostgreSQL** — Migrate from SQLite when performance demands it

## Open Questions

- None — all resolved during brainstorm

## Next Steps

→ Deploy to yari with `sudo nixos-rebuild switch --flake .#yari`
→ Register an admin user on the homeserver
→ Connect a Matrix client and link Signal account via the bridge bot
