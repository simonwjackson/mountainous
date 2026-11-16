# Atlas retired, data retained

Atlas was taken offline on 2026-11-16. Implementation: `98a38eca`.

Rakku sets `mountainous.features.pi-assistant.atlas.enable = false`, not
`atlas = null`. This masks the service, removes its boot-target link and omits
Atlas from generated personal Pi MCP manifests. The `pi-atlas` user/group,
`/var/lib/atlas` persistence declaration and application profile remain.
The app-profile deploy script also excludes retired Atlas from `--restart`.

The source repository at `~/code/sandbox/atlas` was not changed. Flakey's
wind-down and coach wording now says Atlas is retired and offline. This does
not connect those workflows to Mindwtr or change their private storage.

## Deployment and acceptance

| Host | Generation | Running system |
|---|---|---|
| Rakku | 178 | `/nix/store/jlnwzm5r30c2l2kk999yh4qnmpjnccdd-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | 81 | `/nix/store/5a682a242nfx3jvzb170wjs8l1s5kc0a-nixos-system-yari-26.11.20260923.4975466` |

Built Rakku on Unzen and Yari/ARM validation natively on Yari. Checked target
Nix trust and closure integrity. Strict diffs permitted only Atlas's unit and
boot link on Rakku, and four personal skill text files plus derived artifacts
on Yari. Both gateways stayed idle for 96 seconds before the durable switches.
Flakey switched in place; snowy retained its system, configuration, application
profile, container/gateway invocations, sessions, devices and jobs.

Atlas is inactive/masked, not enabled, and port 3180 refuses connections.
`/var/lib/atlas` remains its own btrfs bind mount with `atlas.sqlite` present.
All 10 files across the live Atlas directory and the existing persistent backup
`/home/simonwjackson/backups/atlas/20261116T071225Z/` retained their SHA-256 values.
Twelve protected service identities/states and the application profile stayed
unchanged, including Mindwtr, Google, maps and SparkyFitness. No data was deleted.
Both hosts have no failed units. HA returned HTTP 200; Z-Wave returned its
version handshake. Flakey Mindwtr/calendar reads and both gateways' maps calls
passed. Running skill roots and the three workspace reference copies contain
the new wording. There was no permission, MCP route or workflow rewiring.

Focused Pi resource/runtime/deploy/remote-app and OpenClaw/people/in-place checks,
five Python restart-selection tests, native ARM in-place validation, Nixfmt,
Ruff and focused Statix passed. No aggregate flake check was run. Read-only
proofs and guarded deployment helpers are under `/tmp/claw/atlas-*` on Zao;
remote helpers and results are on Rakku/Yari under `/tmp/claw/`.

## Explicit restoration

Flip `atlas.enable = true` on current cairn and redeploy Rakku. The enabled
configuration is covered by the resource and retirement tests' restore fixture.
Do not use `atlas = null` or remove the persistence mount, user, database,
application profile or backup. Restoration needs none of those to be deleted
or copied back. Prefer this forward change over rolling back an unrelated host
generation. Reversing the retirement policy also needs its production-off test
expectation updated; it must not be bypassed silently.
