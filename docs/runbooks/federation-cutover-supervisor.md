# Zao cutover supervisor — test/implementation only

**Do not invoke this on Zao.** This consumer now implements a continuous root
prepare → local acceptance → network release → relay/host acceptance → boot
persistence → owned guard release path. It is not live approval. The current
review-fix evidence and immutable artifacts are in
`/tmp/federation-cutover-review-fixes.md`. Do not count an implementation
branch, a phase filename, or a fixture result as live acceptance.

## Authority and failure policy

`launch` starts the immutable `korri-cutover-supervisor.service` outside UID1000's
session. The same PID, device lock, gate manifest and **same live
`NetworkIsolation` object** survive ordinary preparation and acceptance. Preparation
no longer exits and loses its receipt. There is no `accept`, `release`, force flag,
caller-supplied executable, successful-status document or success callback.

The independent activation worker executes the generation's actual `test` or
`boot` action. Its invocation is recorded before its handshake permits execution.
The isolation module captures a process-local worker receipt before any evidence
save. Its `emergency_stop()` stops that exact worker and drains the fixed authority
set without reading, saving, deleting or adopting artifact evidence. `close()`
first performs this stop, then attempts normal verified re-masking and permit
retirement. The network module and nft policy are unchanged. The module's public
`permit()` still accepts only Sunshine; the combined consumer owns its inspected
multi-unit permit sequence.

After potential trust mutation, failure stops/re-masks authority, preserves the
new owner and retired trust, and keeps the root supervisor and root-only seqpacket
recovery socket alive. Evidence persistence failure does not prevent stop attempts
or terminate the receipt owner. `failure-held.json` is written only when persistence
is still available. Its containment field distinguishes verified closed gates,
stopped units without a reboot-closure proof, and unknown containment. A file's
mere existence is not acceptance or durable evidence.

No failure restores old pairings, owner events, grants, journals, selectors or
profiles. A changed manifest or guard prohibits deletion/release, not bounded stop
attempts. The writer checks the durable manifest's exact bytes, inode, ownership,
mode and single-link metadata before saves and removals. Drift latches refusal;
it never reconstructs or adopts the manifest from memory. Keep uncertain files
untouched. Failed systemd stop/drain proofs remain **unknown**, not closed.

The nft module still never serializes, reconstructs or adopts a receipt. Receipt
loss needs separately reviewed **closed reboot recovery**. It is exceptional, not
part of the normal successful path. After an uncertain nft removal, gates remain
closed; a table name alone cannot authorize recovery or deletion.

## Required signer and client input

The existing exact old/candidate/secure-recovery generations, bundles, booted and
previous selection, public event/template hashes, host device/owner/event values,
host UUID and grant count remain mandatory. Candidate and recovery generations
must pin the exact approved **new-owner** import. Recovery must use the old runtime
UID/GID contract; candidate must use the new contract. Neither may select the old
owner-bound generation.

The host UUID parser accepts hexadecimal canonical `8-4-4-4-12` grouping in either
case and preserves the supplied bytes. Zao's observed public/persisted UUID is
`6832F97F-A2D5-C30B-2B1C-1D4E31150449`; do not lowercase it. State, grants,
provisioning and public serverinfo comparisons remain byte-exact. This consumer
contract is narrower than the producer's nonempty, at-most-256-byte, non-NUL
string contract; it does not change the producer or host identity.

Additional input is required before any mutation:

| Input | Contract |
| --- | --- |
| `--verification-client-root` | An independently supplied existing client private root and `identity/` directory, root:root `0700`, with single-link `0600` `device.key` and `owner.event.json`. Preflight requires absent federation memory; it never clears cached peers. Never the host identity, a host-key copy, or a Nix store secret. |
| `--verification-device` | Independently approved client public key, different from the host key. Actual OpenSSL derivation and producer identity loading must match it. |
| `--verification-event` and `--verification-event-sha256` | The separately signed client binding's exact public event ID and byte digest. The actual producer verifier must bind this device to `--new-owner`. The host's signed event is not a client binding. |

The signer input for the current Zao cutover is complete. The owner signed the
producer template for a separate verification device. Producer verification and
ordinary import succeeded without changing Zao's identity. The device key stays
in a protected local root. Preflight must still verify the supplied client root,
key, owner event and exact expectations. No owner signing secret is requested.
Synthetic owner 4 exists only in the VM fixture and must never replace this input.
Historically paired Moonlight TLS credentials are **not an input for this operation**.
The user selected `proceed-defer-old-client-probe` in decision
`00ca5161-b453-4991-8474-0273285c28ca`. The canonical decision is
`/home/simonwjackson/code/sandbox/korri/.pi-web/federation-cutover-acceptance-decision.md`.
Only that historical live connection observation is deferred. Evidence explicitly
records that no historical client was tested. There is no deferral flag, generic
acceptance override, PIN prompt, manual pairing step or request to find a client.
All owner, old-trust retirement, grant, restart, isolation, recovery, relay and
other acceptance checks remain mandatory. Configured server certificate/key
metadata, parsing, key match, current validity, CA parsing, config and argv checks
still run before trust mutation.

`owner-verify.rs` uses the producer's `DeviceIdentity`, `FederationResources`,
credentials' native request/response encoding, `NativeClient`, `RpcRequest`,
`RpcResponse`, `Authorization`, `Discovery`, `UpstreamRegistry` and WebSocket relay
transport. The private `peer_rpc` module is not patched or exported. Access to the
actual credentials is through the producer's existing federation resource field.
There is no local encryption implementation or invented wire signature.

Only negative probes use the publicly compromised test owner (secret 3). They
have fresh separately generated device keys, real producer owner templates, real
Nostr signatures and fresh encrypted requests. The old-owner pass is constructed
from `authorization.rs`'s existing pass contract, and actual `Authorization`
first proves it grants catalog access under the **verified old host binding**.
Only exact HTTP 403 from the actual peer server counts as rejection. A timeout,
wrong tag, decryption error, transport failure or malformed response does not.

## Continuous sequence

1. Verify public bindings, separately held keys, current/boot/profile/selection,
   exact successful active-daemon `NoActiveSession`, both managers, empty journal,
   absent pre-cut federation/NIP46 and bounded private fingerprints. Preserve
   host credentials, `.config` metadata, Sunshine apps/config, library/config YAML,
   the device key and signed revocations. Fixed YAML paths are `/var/lib/korri`;
   this implementation requires their reviewed `976:976`, `0600` baseline.
   Sunshine `apps.json` uses its observed `1000:100`, single-link regular `0644`
   baseline, bounded to 4 MiB, beneath the unchanged private `0700` Sunshine
   directory. Fingerprints preserve its content and all recorded metadata; no
   chmod/chown or secret-file exception is introduced. All other file contracts
   remain unchanged. Both-manager evidence uses the isolation module's sole
   actual-UID-1000 authenticated bus path; system-manager queries and gate writes
   stay root. Unknown or failed user-manager evidence remains fatal. See the
   [isolation transport contract](federation-maintenance-isolation.md#contract).
2. Install all persistent conditions and runtime masks, install and verify the
   exclusive nft table, repeat exact idle, then stop/drain. Perform actual
   all-client retirement, preserved-key owner replacement, offline bundle select,
   real candidate test activation and actual stale-grant reconciliation through
   the real Sunshine seqpacket listener. `previous` stays unchanged.
3. Inspect the materialized candidate and loaded startup policy. Permit only the
   fixed system authority set, retaining every legacy user mask. Start the actual
   identity importer, Sunshine, input authorities and selected korrid. Require
   exact local-control idle, empty journal, source guard availability, actual
   `/proc/PID/exe` images and all four kernel UID/GID fields. Nix makeWrapper exec
   targets are resolved during **preflight**, before any trust mutation. Only ELF,
   a complete constant-export makeWrapper grammar, and the actual Sway wrapper's
   declared `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` branch are supported.
   No shell wrapper is executed for inspection. Inputd uses `Group=korri-control`,
   GID 977, matching the actual Zao producer. Loaded legacy retirement names outside
   the four fixed user gates, including `korri-compositor`, `korri-sunshine` and
   `korri-session.target`, must be proven absent; inactive is not absence.
4. Require the actual Sunshine command to name the inspected config and target
   the exact trust document. This checks `config.cpp::path_f` and Linux
   `appdata()`'s HOME/XDG/ConfigurationDirectory rules, including the producer's
   default `sunshine_state.json`. Exactly one config argument is allowed. The only
   supported tails are empty, `log_path=/dev/null`, or that log argument followed
   by `encoder=nvenc`, as used by the real Zao producer. Their producer semantics
   affect only the log destination and encoder, not state or listener selection.
   Config inspection requires effective base port 47989, the fixed certificate/key
   paths, and the supervisor's network namespace. That base port fixes the one
   nvhttp TLS endpoint `127.0.0.1:47984` recorded once in the module and shared by
   the certificate checks and the readiness gate below. Unsupported overrides, duplicate
   settings, list continuations, migration and alternate state paths refuse before
   mutation. Loaded Sunshine argv and namespace are checked while startup gates
   still lack permits. Require absent/empty **both** named and legacy memberships.
   A lossless canonical digest excludes only those membership fields and preserves
   all other state, including credentials and history, across activation,
   reconciliation, acceptance, boot and release. Restart Sunshine and require
   empty persisted named/legacy memberships again. Require actual encrypted
   new-owner catalog/source success, host-UUID attestation, exact tagged session
   idle and peer-list availability, plus fresh known-test-owner and valid-old-pass
   rejection. Recheck the preserved state and client identity.

   Generate one short-lived RSA TLS key and certificate at runtime in the exclusive
   root:root `0700` `automatic-probe/` evidence directory, each single-link `0600`.
   They are never exported into Nix or printed. Record the mutation intent before
   the first RPC. Using the separately signed verification device and existing
   encrypted `peer_request` adapter, send the producer's typed
   `MoonlightCertificateProvisionRequest`. Require authenticated typed success
   and the exact configured server certificate in the response. No local
   unauthenticated provisioning operation is used.

   Require exactly this device's grant, its exact owner statement/certificate/host,
   exactly one matching temporary Sunshine membership, and preserved non-membership
   state and all other baseline facts. The actual certificate-control writer uses
   `mkostemp`, `fchmod(0600)` and atomic rename. Its state file therefore changes
   from baseline `1000:100` to the inspected Sunshine process's `1000:980`. Require
   GID 980 immediately after both authenticated writes. The state reader allows
   only those two groups, still UID 1000, single-link, nofollow and `0600`; preflight
   and offline retirement still require GID 100. No other file's metadata contract
   changes and no chmod/chown repair runs. Connect to actual Sunshine HTTPS with the
   new certificate. Validate the server certificate, pin its exact DER, and require
   XML 200, PairStatus 1 and the exact host UUID. Before the next RPC, repeat all
   temporary-grant, membership, client identity and preservation checks. Send only
   this certificate through authenticated `MoonlightCertificateRevokeRequest`.
   Require typed `Ok` with `removed=true`, empty grant/client trust, and actual XML
   401 certificate-verification denial before and after another Sunshine restart.
   Start korrid only if it is neither active nor activating after that restart;
   socket activation may already have done this. Still require exact authenticated
   idle and the selected runtime. Never reset or disable systemd start limits.
   A socket/TLS error alone is not denial. This observes rejection of a **NEW
   temporary certificate after revoke**, not a historically paired client.
   `automatic-revoked.json` records completion only after all those checks.

   Every stop signal this sequence sends to Sunshine, and every fresh Sunshine
   start it makes, is guarded by a bounded wait for **actual Sunshine readiness**.
   See [Sunshine readiness before any stop signal](#sunshine-readiness-before-any-stop-signal).
5. Only now remove the exact owned nft table by its live receipt. Persistent gates
   and owned runtime permits remain. Use the daemon's configured relay list with
   actual WebSocket discovery/publication, verified host endpoint discovery,
   authenticated native routing and Ready state. The first discovery wait requires
   an empty producer peer directory. Cached valid endpoints cannot satisfy it when
   configured relays are unavailable. Check the daemon's peer list. Shut down/join
   client discovery, then reopen actual producer memory without a discovery task
   and authenticate remembered routing again.
6. Invoke the actual candidate `sw/bin/zao-verify-commitments`. All six exact PASS
   lines and `6 passed, 0 failed` are required. Recheck runtime, idle, preserved
   state, and local SSH/manager continuity. Stop/re-mask before boot persistence.
7. Set the explicit `/nix/var/nix/profiles/system` profile with actual `nix-env`,
   execute the candidate's actual `boot` action in the independent worker, and
   inspect systemd-boot's exact default entry and its sole `init=` generation.
   Refuse EFI entry overrides/BootNext. Verify the immutable new-owner importer
   and exact selector again. Restart and verify the final runtime **under the
   existing persistent gates and runtime permits**. Sync `released.json` and its
   owned manifest receipt while all reboot conditions remain intact. This is the
   durable release decision. Only afterward remove exact owned conditions, masks
   and permits, then reload and recheck the same running processes without a
   restart. Retain evidence and GC roots. Success is printed only after cleanup.

A failed save through the durable release decision leaves all persistent boot
conditions intact. Runtime permits disappear on reboot. After the durable decision,
a cleanup failure still stops authority and retains the receipt, but must not be
called reboot-closed: some conditions may already be removed from the accepted
new-owner generation. `released.json` now records that durable decision, not proof
that cleanup finished. Inspect its manifest receipt and actual guards/runtime;
neither a phase filename nor a partially written record authorizes release.

## Sunshine readiness before any stop signal

`systemctl restart sunshine.service` sends SIGTERM. Sunshine installs its terminate
handler early in `main()`, but that handler only takes effect once `mainThreadLoop`
runs. A signal that arrives while the leader thread is still doing start-up work is
not acted on, systemd waits out the whole 90 s `stop-sigterm` timeout, the 30 s
manager call has already expired, and the supervisor can only record
`{"containment": "unknown", "reason": "systemd operation failed: restart"}`. This
race predates the user-bus transport change; observed passes won it by 26-270 ms.

`restart_sunshine()` is the supervisor's **only** restart of `sunshine.service`. It
waits for readiness and then issues the restart, so the acceptance restart and the
automatic-probe restart cannot be issued without the wait and a later caller cannot
reintroduce the race by forgetting it. `await_sunshine_ready()` is also called after
every fresh start of the unit: the maintenance-permit start, whose block ends by
stopping Sunshine again, the matching-candidate start and the final release start.
It is a wait for evidence, never a delay, retry or longer timeout. One observation
requires all of:

- systemd reports `ActiveState=active`, `SubState=running` and a positive `MainPID`;
- the actual listening endpoint `127.0.0.1:47984` - the same one the certificate
  checks use - completes a TLS handshake presenting the exact pinned server leaf.
  No client credential is offered, so nvhttp treats the peer as unauthorized: it
  cannot pair, launch or change any trust state;
- the kernel reports that the `MainPID` leader thread is parked in a timed wait
  (`/proc/<pid>/syscall` `clock_nanosleep`/`nanosleep`, or equivalently
  `/proc/<pid>/wchan` `hrtimer_nanosleep`);
- the same `MainPID` still holds after those observations.

The listening endpoint alone is **not** sufficient and must not be used alone.
Measured on the real systemd 259 / Sunshine VM over ten starts, the endpoint first
answers 56-80 ms **before** `Starting main loop` - inside the exact failure window.
The leader thread reaches a timed wait only inside that loop; every start-up wait
observed was a poll, futex, pipe or file wait. Both kernel views of the same wait
are accepted so that a kernel which restricts one interface still satisfies the
gate; a kernel that exposes neither produces a bounded refusal.

The wait is bounded at 60 s. Measured readiness is 0.24-0.52 s after the unit goes
active. A timeout raises `Sunshine did not reach actual observable readiness`, which
refuses and contains exactly like any other gate. It never proceeds, never retries
the restart, never relaxes `TimeoutStopSec`, never resets or disables systemd start
limits and never downgrades the provision/TLS/revoke, idle, journal, preservation or
containment checks. Containment paths (`emergency_stop`, `close`) are unchanged and
deliberately do not wait: containment must stay prompt.

`restart_sunshine()` deliberately does **not** wait on the instance it just started.
A variant that waited immediately after the restart refused after its full bound and
contained (`{"containment": "closed with verified persistent gates", "reason":
"Sunshine did not reach actual observable readiness"}`). The recorded cause is a port
conflict, not a korrid dependency: in `vm-postrestart-attempt.log` the restarted
Sunshine died at monotonic 96.260737 with `Couldn't start http server on ports
[47984, 47984]: bind: Address already in use`, so it never became ready. Socket
activation had already returned `korrid.service` 13.7 ms after the restart, while the
supervisor was still blocked in that wait.

The restarted instance is therefore covered by later evidence rather than by a wait.
The probe path requires an actual XML denial from the restarted listener before it
continues, which proves that listener serves. The remaining normal-path stop of that
instance is `persist_boot`'s `isolation.close()`, which does not wait, because
containment must stay prompt. **Residual risk:** if that stop ever reached a
starting Sunshine, the supervisor would report unknown containment, exactly as the
race above. Measured margin in a passing run is 2.74 s of intervening work, against a
start-up window of roughly 0.26 s. This margin predates centralised restarts; it is
incidental timing, not a guarantee.

`tests/federation-cutover.nix`'s `restartrace` node in the probes suite runs the
real binary under real systemd 259. It reproduces the race with one unguarded
restart, requires three restarts through `restart_sunshine()` to signal only a
running main loop and to log `Terminate handler called` after it, and requires a
stopped Sunshine to exhaust the bound and refuse without changing `NRestarts` or
`ActiveState`. Each observation reads the journal of exactly one systemd invocation
id, so an earlier instance's stop can never be counted as the observed one.

The accompanying unit test asserts that `manager.call("restart", …)` appears only
inside `restart_sunshine()`, after the wait. It catches a direct restart elsewhere, a
deleted or reordered wait, and a restart hidden in a nested function or method. It
does not catch a direct `stop`, a `try-restart`, a verb passed through a variable, or
a `systemctl` subprocess. Treat it as a guard on the one known regression, not proof
that no future path can signal Sunshine.

The fixed library metadata and Sunshine state-target requirements may refuse a
different real baseline.
Do not chmod live files or loosen expectations just to satisfy this implementation.
Review the actual producer's deployed modes and supply a scoped implementation
change if needed.

## Explicit secure software recovery

`recover` connects to the surviving root supervisor. Its full arguments must match
`baseline.json`; the socket peer PID must be that supervisor. The only request is
the already pinned secure recovery plan. It does not replace the running process
or borrow another process's nft receipt. EOF, reset, timeout and acknowledgment
errors are contained within each connection. No mutating operation starts until
acknowledgment succeeds. Once it starts, requester death does not cancel or replay
it. Repeated requests cannot bypass changed journal/grant or selector evidence.

Recovery first closes everything and verifies new owner/trust/key. With an exactly
empty journal, it can retry the **matching selected candidate** activation under
gates/isolation, finish real stale-grant reconciliation, start that candidate and
obtain fresh exact active-daemon idle. It closes again and repeats empty
journal/grants before offline-selecting the secure old-software/new-owner bundle.
It test-activates and starts that actual selected old binary under isolation,
requires exact idle again, and persists its explicit `boot` profile/action while
all persistent gates remain. The actual six commitments and management continuity
must pass before downgrade, in the recovery runtime, and after boot persistence.
Only unchanged original stale grants may be reconciled before preparation finishes.
Any unexplained grant introduced after preparation, or any populated journal,
prohibits recovery selection. The only successful temporary grant removal is the
mandatory authenticated revoke inside the automatic probe. Recovery never performs
that cleanup. An incomplete automatic probe also prohibits recovery, even if no
client/grant remains visible: an RPC or durability failure can leave an uncertain
write. There is no finally-revoke, automatic retry, grant deletion or certificate
cleanup on failure. Retain the protected probe credentials, mutation intent and
all new/unexplained facts for separate recovery review. It does not claim federation feature acceptance for
old software or automatically release recovery guards.

A populated journal is not a request to delete facts or downgrade. The matching
closures, evidence and closed supervisor remain available for a separately
reviewed controlled journal recovery. After successful gated software recovery,
the boot record explicitly names the recovery generation. No automatic old-state
fallback exists. Receipt-loss reopening and post-recovery guard release remain
manual reviewed work, not acceptance overrides.

## Verified local result

The approved automatic-probe change passes **32 unit tests and 18 actual VM
subtests**. Exact source snapshots, red/green logs, immutable package equality,
retained roots and remaining live boundaries are recorded in
`/tmp/federation-approved-probe-change.md`. All 69 original producer Rust source
files remain byte-identical to the immutable d39ea55d export. The supervisor and
verifier have separate retained worktree roots; these are not the older
`result-federation-new-owner-verifier` artifact.

| Latest suite | Subtests | Test-script seconds |
| --- | ---: | ---: |
| Normal lifecycle, preflight, secure recovery and reboot | 6 | 491.66 |
| Failed authenticated revoke and failed revoke receipt, with repeated recovery refusal and reboot | 2 | 284.75 |
| Actual manifest open-denial containment | 5 | 566.34 |
| Journal, grant, commitment, non-membership and legacy-membership preservation | 5 | 636.50 |

The probe failures retain either the exact new grant/membership or verified empty
trust after revoke, without letting uncertainty permit recovery. Only the test's
own reboot-observation file is fsynced; no global sync hides supervisor durability.
The public `--probes-only` runner also passes against the same immutable outputs.
These are isolated fixture results, not on-device acceptance.

The earlier review-fix run passed six combined lifecycle subtests in 485.76 seconds,
five real fanotify `manifest.next` open-denial cases with actual service/socket
stops, peer probes and closed reboot attempts in 538.65 seconds, and five
acceptance-time fact cases in 492.67 seconds. The fact cases cover journal, stale grant, unrelated
media commitment failure, non-membership state change and legacy membership.
Repeated real recovery requests leave those facts and selectors/profile unchanged.
The lifecycle run also kills real recovery request clients before a request and
after acknowledgment, and runs actual preflight refusals for shifted/extra state
configurations, malformed/mismatched TLS keys, expired server credentials and a
loaded transient legacy authority. The 13-subtest isolated gate regression passes
in 170.08 seconds. Exact artifacts, red/green evidence and hashes are in
`/tmp/federation-cutover-review-fixes.md`. Independent final review resolved all
nine reported findings and found no new blocker in the fixes. It reran 29 unit
tests and verified immutable artifact equality. See
`/tmp/federation-cutover-final-review.md`. This does not replace live preflight or
acceptance.

`tests/run-federation-cutover.py` builds/tests locally only. Its default full run
includes lifecycle, automatic-probe-failure, filesystem-fault and acceptance-fact
VMs. `--smoke`, `--probes-only`, `--faults-only` and `--proofs-only` select bounded
iteration suites, not substitutes for the full run.

## Fixture and live-proof limits

The combined fixture uses actual systemd 259, candidate korrid, the selected actual
old korrid recovery binary, actual Sunshine, actual primitives, Nix activation,
systemd-boot and real reboot. Baseline signed owners/client identities and TLS
credentials are synthetic. The baseline certificates use fixed 2020–2100 validity
(plus an intentionally expired negative fixture); the guest RTC starts at
2026-09-06 with NTP disabled. Cached build dates cannot expire those positive
fixtures. The automatic probe certificate/key is instead generated inside the
running guest, with one-day validity, and never exported into the build output.
Production TLS/date validation is unchanged.
Only the old pre-cut idle transport is the existing configurable Unix server.

The six-check executable comes from `hosts/zao/commitments.nix`. Its only change
adds `findutils` to runtime inputs: the existing zram check calls `xargs`, which
was missing in the supervisor's clean environment. No commitment predicate or
service behavior was weakened.
Fixture topology uses real XFS loop mounts and mergerfs, real systemd targets and
timers, real Jellyfin health, real CUPS/Avahi queue state, real Tailscale registered
to an isolated real Headscale server, and actual zstd zram. It omits physical by-id
disk expectations. A real local TCP proxy replaces only external tsnet topology;
long-delay fixture timer jobs do not prove SnapRAID or media-mover work. No fake
systemctl exists. Discovery uses actual strfry in a separate network namespace.
The shipped transport allows plaintext WS only on loopback, so a real UID976 TCP
route forwards that loopback connection across the veth. The unchanged UID976
nft policy blocks the route before local acceptance. No relay crypto, schema or
success result is replaced. Public WSS/NIP-42 policy remains live proof work. Xvfb/software encoding and selected sleep processes
stand in for physical compositor/input hardware only.

A green fixture does **not** prove the live NVENC/Intel VAAPI configuration,
physical input/video/Android behavior, real clients' old private-key custody,
public relay policies/NIP-42 interoperability, remote SSH/Tailscale continuity,
Zao's disk IDs, media contents, printer hardware, or accepted live generations.
The boot proof covers the tested primary systemd-boot ESP. Zao's redundant ESP
mirror and firmware fallback/order need separate real deployment review; the
host's existing mirror command can skip an unavailable backup. Do not infer that
proof from a primary profile symlink or a VM boot.

Other authorized new-owner clients must not launch sessions or add grants during
acceptance. A concurrent authorized launch creates journal facts and blocks
software downgrade. The gates do not delete journals or stop arbitrary game units
to manufacture idle. The actual peer-RPC producer reconciles stale certificates
before native requests. The consumer checks empty journal/grants before the next
probe, including after local-acceptance evidence is saved. This catches the tested
phase-boundary insertions without altering facts. It is not an atomic freeze of
in-flight RPCs against a non-cooperating concurrent grant writer. Such a stronger
contract would require separate producer/coordination work, not a consumer override.

Costs: a full maintenance outage, every old Sunshine client needing new trust, an
extra independently approved verification-device binding, retained protected temporary
probe credentials and large isolated VM closures, and explicit cooperating-administrator,
firewall, selector and store-GC exclusion. There is no safe automatic downgrade of
a populated candidate journal.
