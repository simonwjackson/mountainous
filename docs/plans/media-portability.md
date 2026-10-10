# Portable media services: implementation and acceptance plan

## Status and scope

The operator approved [controlled moves and local staging](../decisions/media-portability.md). This plan is not an implemented or deployed media stack. Live cutover and application-data transfer remain separate approval gates.

The initial application scope is Sonarr, Radarr, Prowlarr, NZBGet, and Transmission. Runtime requirements include service identities, protected credentials, completed-file access, downloader VPN isolation, and library staging/movement. Jellyfin and long-term media remain on Zao. Messaging and Syncthing remain excluded.

Do not reinstall or format either host. Do not run Disko or fresh-install deployment workflows. Preserve Yari's operator account, SSH identities, disks, and unrelated application state. Do not create a chargeable Oracle boot-volume backup.

## Verified baseline on 2026-10-10

| Observation | Evidence and limit |
| --- | --- |
| Unzen runs x86_64 NixOS 26.11. | A live read-only probe verified SSH against its enrolled installation fingerprint. |
| Unzen has about 1.8 TB available on the filesystem containing `/var/lib`. | The probe reported 1,799,634,087,936 available bytes. Capacity alone does not prove migration readiness. |
| Unzen has none of the five application units or the VPN namespace unit. | Live systemd inspection returned `LoadState=not-found`. The expected media and cross-host library paths are absent. |
| The current three downloader/indexer proxies cannot log in. | Each logs `invalid key: API key does not exist`. Their `usenet`, `torrents`, and `indexers` nodes are offline and expired. |
| NZBGet responds through its local backend. | Authenticated version RPC returns HTTP 200 through `10.200.200.2:6789` and VPN-local loopback. The configured Tailscale address times out. |
| Completed-download handling is enabled in both ARR applications. | Both report unavailable download clients and empty queues. Sonarr's read-only review accepts the existing Sunny S18E03 file without submitting an import. |
| The mover's local media source is absent. | The live script uses `/srv/basin/media`. Its empty-directory cleanup deletes the root itself. An isolated local fixture reproduces that behavior, but not its historical execution on Yari. |
| NZBGet reports downloads paused and no visible completion history. | Moving the service does not recreate missing historical records or authorize recovery imports. |
| Recent recorded imports predate proxy-node expiry. | Sonarr last recorded an import on August 18 and Radarr on August 1. The first cause and date of stalled imports remain unknown. |

Private diagnostic logs remain outside Git. Do not include credentials, private identity state, or full unredacted API/settings dumps in evidence files.

## Portability contract

| Concern | Required behavior |
| --- | --- |
| Service address | Preserve existing service names independently of physical host placement. Applications do not depend on sharing a host. |
| Application state | Preserve records, configuration, client credentials, categories, queue state, and required work files. Capture a consistent snapshot while all writers are stopped. |
| Network identity | Use OAuth-backed tagged enrollment and an explicit protected identity-state directory. Preserve the identity during routine moves and permit only one active owner. |
| Placement | Declare the host separately from application configuration. Generate required mount or path-mapping changes from placement rather than requiring manual client setup. |
| Staging | Use the downloader host's local disk. Expose completed files to authorized remote ARR hosts through managed file access. A stable HTTP endpoint alone does not expose those files. |
| Library | Keep application-visible library paths stable across placements. Long-term media remains on Zao. Preserve required local library roots when the mover prunes empty title folders. |
| Runtime release | Preserve the deployed application release for the first move where a compatible target build is available. Do not combine relocation with an unreviewed database-schema upgrade. |
| VPN runtime | Reuse the operator's VPN access across eligible hosts. Unlimited-system entitlement is not a placement limit. Verify concurrent use of the existing configuration before requiring separate profiles. Preserve the source tunnel for applications that remain there. |
| Credentials | Give the target only the credentials it needs. Encrypt transfers containing credentials. Never print credentials or put them in visible command arguments. |
| Ownership | Preserve or deliberately map file ownership and group access. Do not assume dynamically assigned service IDs match across hosts. |
| Rollback | Retain protected recovery state. If the target writes state, recover its newest compatible state instead of restarting an obsolete source snapshot. |

## Existing pattern to reuse

[The CLIProxyAPI migration](../research/rakku-cliproxyapi-migration.md) records a controlled move that stopped source writers, verified an encrypted transfer, preserved its dedicated endpoint, and allowed one active identity. This is existing project evidence, not fresh verification of that deployment here.

`modules/cliproxyapi.nix` separates host-owned accounts, permissions, persistence, startup gates, and units from an application profile. Its sidecar has an explicit identity-state path. Reuse those safety properties, not its automatic-update policy or retired-source deletion policy.

Unzen does not use Rakku's disk/persistence layout. Do not copy hardware-specific persistence paths from that module without checking the target storage contract.

## Implementation slices

1. Inventory source state and dependencies.
   Record actual data directories, releases, service ownership, effective proxy-state paths, service names, credentials needed, and download work files. Separate queued work from existing archives and completed files. Do not assume unreferenced files are disposable.
2. Build the service-identity runtime.
   Add explicit identity-state handling, OAuth-backed tagged enrollment, protected credential delivery, and redacted failure handling. Verify effective state paths rather than assuming the proxy honors an environment variable. Re-enrollment must not delete unrelated devices or replace a live owner.
3. Add host placement and runtime contracts.
   Use disabled-by-default features and forward options to upstream `services.*` modules. Keep application settings independent of host assignment. Preserve source releases or flag incompatible target builds before planning activation.
4. Add local staging and cross-host access.
   Create required roots with deliberate ownership. Generate completed-file access and library mounts from placement. Require working storage before applications start. Do not expose partial work or secret state unnecessarily.
5. Add and test downloader VPN isolation.
   Preserve the source VPN routing requirements. Yari currently shares one WireGuard namespace/profile across its downloader and indexer applications. The operator confirms VPN access across unlimited systems. Test simultaneous reuse of the existing configuration before splitting services; do not require separate profiles by default. Do not stop the source namespace while other applications still use it. Test loss of the tunnel and blocking of ordinary internet routes. Keep storage and control connections working without allowing downloader internet traffic outside the tunnel.
6. Prepare gated Unzen configuration.
   Build target packages and units with application startup closed. Verify credentials, storage, ownership, and rollback prerequisites without using active service identity state on both hosts.
7. Prepare the controlled move tool.
   Add explicit source/target ownership checks, consistent state capture, protected transport, byte and permission verification, acceptance receipts, and state-compatible rollback. Retain source files by default.

No live service is enabled merely because its configuration evaluates or builds.

## Tests required before cutover

| Test | Acceptance |
| --- | --- |
| Split placement | ARR on one host can reach a downloader and its completed files on another host. Client configuration does not require manual reset. |
| Identity move | The existing service endpoint reaches the target after a controlled handoff. The source cannot run the same identity concurrently. |
| Enrollment recovery | Expired or absent registration can recover with valid OAuth credentials. Revoked credentials fail without disclosure or unrelated device deletion. |
| State transfer | Application records, client identities, categories, queue/work state, bytes, and access permissions match the approved source snapshot. |
| VPN failure | Download traffic cannot escape through the ordinary host route when the tunnel fails. |
| Split VPN placement | The chosen configuration works concurrently on the intended hosts without disrupting source applications. Reuse the existing profile when supported; require a separate profile only if concurrency checks establish that need. |
| Storage failure | An absent required mount prevents startup or import rather than silently writing into an empty mountpoint directory. |
| Empty-directory cleanup | Empty title folders can be removed, but media and library roots remain. Nonempty files survive. |
| Failed target startup | The source can resume from compatible current state without two active owners. |
| Media processing | After separate approval, a representative import and library handoff succeed. RPC health alone is not proof that media processing works. |

## Approved-cutover procedure, not yet authorized

1. Prepare and verify the target with startup gated closed.
2. Obtain approval for the service cutover and the exact state/work-file transfer scope.
3. Pause work and stop all source application writers and its proxy.
4. Capture protected consistent state and transfer required work files.
5. Verify transferred bytes, ownership, storage paths, and runtime compatibility.
6. Start the target as the sole owner and check the unchanged authenticated client endpoint and application records.
7. Record acceptance or roll back using the newest compatible state.
8. Keep the source stopped after acceptance. Retain its state until the operator separately approves cleanup.

Keep download-pause state during initial recovery. Normal processing, representative imports, and recovery of old completed files require explicit approval. No step authorizes speculative deletion.

## Costs and remaining risks

The operator confirms VPN entitlement across unlimited systems. Concurrent reuse of the exact same WireGuard configuration is not yet verified. [WireGuard's endpoint tracking](https://www.wireguard.com/#built-in-roaming) uses a peer's most recent authenticated endpoint, so entitlement alone does not establish identical-profile concurrency against one server. This is a validation item, not a blanket requirement for new accounts or profiles. No VPN credentials have been changed.

Local staging consumes disk on the chosen downloader host. Downloader moves transfer work files and take bandwidth and time. The handoff pauses the moved service; it does not provide automatic failover or zero downtime.

Remote ARR access depends on the network and correct filesystem permissions. Tagged identity enrollment prevents routine node-key expiry, not credential revocation or network failure. Mutable application-state schemas can limit rollback even when executable profiles roll back successfully.

The current missing completion history and paused downloads are separate recovery work. A portable deployment does not establish that every archive is complete, every old download is importable, or every pending file is disposable.
