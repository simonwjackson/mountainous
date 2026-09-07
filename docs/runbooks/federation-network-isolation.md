# Federation maintenance network isolation slice

**Import-only primitives and an isolated VM test, not a live cutover runbook.**
Nothing imports this into Zao, changes a generation, or enables it at boot. The
separate [systemd isolation slice](federation-maintenance-isolation.md) owns
persistent per-unit startup gates. This slice does not edit that implementation.

## Fixed contract

`scripts/federation_network_isolation.py` and its adjacent
`federation_network_isolation.nft` install one exclusive nft `inet` table named
`korri_maintenance_isolation`. Both input and output hooks use priority **-310**,
before ordinary iptables filter hooks and their established/trusted accepts.
There is no established-connection exemption in this table.

| Traffic | Temporary policy |
| --- | --- |
| Non-loopback inbound TCP destinations | Drop `39217,47984,47989,47990,48010` on every interface, IPv4 and IPv6. |
| Non-loopback inbound UDP destinations | Drop `47998,47999,48000,48002,48010,60000-61000` on every interface, IPv4 and IPv6. |
| Non-loopback outbound service source ports | Drop the corresponding TCP/UDP sets, including established flows and unsolicited output. |
| Non-loopback output owned by UID 976 | Drop all protocols and destinations, including an already-established relay on TCP 443. |
| Loopback requests to those service destinations | Root passes through to existing policy. Other socket UIDs receive TCP reset or ICMP port-unreachable, even on established sockets. This includes requests to the host's own non-loopback IPs routed over `lo`. |
| Other traffic | Fall through to existing policy. No global UID 1000 block, conntrack flush, global ruleset flush, policy change, or management-service operation. |

The new chains' implicit accept policy means **continue through other hooks**,
not bypass the host firewall. The module changes no existing chain policy.

Loopback filtering checks the **request socket's UID**, not application
credentials. Root maintenance still needs the real API authentication. A reply
from the UID 976 maintenance server to the root client remains possible.
Already-buffered data and unsolicited server-to-client loopback replies are not
withdrawn by a destination-port request rule. Stop existing authorities/sessions
with the separate gates before opening the narrow Sunshine maintenance phase.
This is not a substitute for service quiescence or client trust retirement.

## Ownership and failure contract

The public interface is `NetworkIsolation(nft)` with `install()`, `verify()`, and
explicit `remove()`. There is no executable main, context-manager cleanup,
exception rollback, configuration schema, or automatic table adoption.

- The module, adjacent rules, and explicit nft executable must be read-only,
  root-owned Nix store files. The future runner must root that closure and its
  interpreter before maintenance.
- `install()` invokes the immutable rules file in **one** `nft -f` transaction.
  Its first command is `create table`, not `add table`. A name collision fails
  atomically rather than altering an existing table. A failed or unknown result
  does not trigger cleanup. Failure before commit creates no isolation; failure
  after commit can leave an unowned table. Neither permits the caller to advance.
- `nft --echo --json` returns the handle created by that transaction. A private
  in-memory receipt binds that handle and the entire table's JSON objects and
  handles to the current boot ID and network-namespace inode/device. No counters
  or mutable timeout elements make the snapshot change during ordinary traffic.
- `verify()` checks that exact receipt. `remove()` first verifies every object,
  then deletes the table **by handle**, not name. Changed contents, a same-name
  replacement, a different network namespace, an absent table, or a missing
  receipt refuses removal. A name replacement after deletion is left intact.
- Every `Refusal` requires inspection and retention of the **separate persistent
  gates**; it is not proof that the network table exists. After deletion is
  attempted, a failed/unknown command result or failed post-delete listing raises
  `RemovalUncertain`, a `Refusal` subclass: **the table may already be absent**.
  Keep separate persistent gates in place and require supervisor inspection.
  The receipt remains, but a retry cannot complete successfully if deletion
  already committed: exact verification refuses the absent table. There is no
  deletion-by-name, adoption, or automatic restoration as compensation.
- Stopping the installer does not remove the kernel table. Losing the process
  also loses its receipt: a new object cannot adopt or remove the table. That
  trades automatic recovery for fail-closed inspection. Any durable receipt
  recovery belongs in the reviewed parent runner, using its ownership evidence;
  this slice does not introduce another disk metadata format.

The caller must exclude concurrent privileged firewall/admin writers. A table
handle prevents deletion of a replacement after a name-check race. It does not
provide a compare-and-swap against an administrator changing the *same* table
between the contents check and deletion. No mechanism here resists hostile root.
Do not call `remove()` merely because a later operation failed. Only the parent
can prove that release is safe.

## Verification

Run the standalone test, without staging or importing any host:

```sh
python3 tests/run-federation-network-isolation.py --log-dir /tmp/federation-network-isolation-check
```

The entry resolves the **root nixpkgs input reference** in `flake.lock`, checks
its NAR hash, and invokes `nix-build tests/federation-network-isolation.nix`.
It does not deploy, inspect a live host, or read private credentials. Generated
SSH keys belong solely to the isolated fixture. The VM asserts systemd **259**.

`tests/federation-network-driver.py` and `tests/federation-network-peer.py` run
real sockets in the guest and a peer network namespace. Two veth interfaces
include a trusted `tailscale0`. Real iptables `ts-input`, `ts-forward`, and
`ts-postrouting` chains exercise early accepts and retain exact rules/jumps.
The test does not run tailscaled or contact its control plane.

The behavioral matrix establishes every named TCP/UDP service-port connection
before installation on both interfaces/families. It samples the UDP range at
60000, 60500, and 61000, with allowed neighbors 59999/61001. It then tests existing
and new blocked requests, autonomous server output, explicit service-source-port
clients, UID 976 relay traffic, and root/976/1000/1001 loopback clients. Actual
server receive logs must contain none of the denied request payloads.

Four original IPv4/IPv6 SSH processes, across both interfaces, exchange fresh
payloads throughout; they are never replaced to claim continuity. Separate new
SSH connections also succeed. Other real TCP/UDP probes cover UID 1000, TCP 443,
UDP 41641, and DNS/DHCP ports. These are transport probes, not DNS/DHCP/DERP
protocol acceptance tests.

The VM runs its actual pinned NixOS iptables `firewall.service` **stop, start,
reload, and restart**. The same established TCP/UDP sender sockets transmit across
each operation. Worker control acknowledges start only after successful writes on
all sockets, proves live per-socket write progress immediately before and after
each action, and acknowledges stop only after worker quiescence. The sender pauses
between actions while discrete negative probes run. The guest alone raises
`net.core.wmem_max` to 4194304 and requests 4 MiB socket send buffers, checking
that Linux grants the capacity. This leaves room for fresh writes on the same
sockets despite retained denied bytes. Worker failure or stalled progress fails the
check; `BlockingIOError` counts as blocked, never as a successful write. Real TCP
reset tests cover both paused and active workers; a real backpressure test checks
reported bytes against bytes received and rejects stalled progress. No payload
may reach the service during firewall actions; table contents and management
rules must remain unchanged. New and established negative probes also run after
each action. This establishes progress around each action, not packet coverage
of every sub-millisecond scheduling interval.

Ownership tests exercise a foreign install collision, a kernel transaction
failure after table/chain creation commands, contents mutation, same-name
replacement, stale-handle deletion failure, namespace mismatch, exact cleanup,
and installer exit. An immutable guest adapter also runs real nft with a delay
before installation, after committed installation but before returning its echo,
and after committed deletion but before returning its result. A fourth case
fails the post-delete listing. Tests inspect actual kernel tables, journal every
adapter invocation, and require receipt refusal without compensation or adoption.
Both uncertain deletion cases require the phase-specific diagnostic and refusal
on stale-receipt retry. The adapter never invents successful nft operations.

A final crash/reboot proves that the kernel table is **absent** after boot.
**Reboot safety remains the persistent systemd startup gates.** This network VM
does not import or prove the other slice's gate integration, old/candidate/recovery
generations, activation drain, identity/trust operations, or physical streaming.

## Costs and unverified boundaries

- The three 15-second nft timeout injections add about 45 seconds to the VM;
  real sender backpressure adds about 9 seconds. A slow firewall action that
  exhausts TCP send capacity now fails the test rather than claiming progress.
  None of these tests makes deletion and receipt updates atomic or proves
  supervisor recovery, durable ownership, or persistent gate integration.
- All non-root local service requests and the listed UDP range are unavailable
  during maintenance. UID 976 cannot use external DNS or any other network
  service while isolated.
- A source-port block also affects unrelated applications that explicitly bind,
  or receive an ephemeral allocation in, that set. In particular, UDP 60000-61000
  overlaps common ephemeral ranges. The VM bounds automatic ephemeral allocation
  to 32768-39000 for deterministic unrelated-traffic tests; it does **not** change
  Zao's range or claim arbitrary overlapping UID 1000 traffic survives.
- TCP may retransmit queued bytes after release. Isolation does not erase socket
  buffers, stop authorities, terminate sessions, or retire trust. Those remain
  prerequisites owned by the parent cutover.
- The VM disables login/SSH WTMP recording because the pinned minimal fixture's
  `pam_lastlog2.so` has the already-observed unresolved `pam_syslog` symbol. Real
  PAM and SSH authentication still run. No production PAM change is included.
- Actual Tailscale/WireGuard/DERP connectivity, live management source ports,
  production firewall extra commands, other network namespaces, forwarding/NAT
  of container services, offload arrangements, and live Zao state are unverified.
  The fixture tests the pinned iptables backend, not an arbitrary administrator's
  `flush ruleset` or an enabled `nftables.service`.

No cutover should consume this slice until parent review and the separate
quiescence, persistent-gate, ownership, trust, selector, and release proofs exist.
