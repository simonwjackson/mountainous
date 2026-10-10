# Portable media services: implementation and acceptance plan

## Status and scope

The operator approved [controlled moves and local staging](../decisions/media-portability.md). The operator also approved `migrate-preserving-state`: implementation, tests, deployment, source service stops, protected application/work-file transfers, and paused target startup verification. Downtime is acceptable. Expired service enrollment can be repaired without deleting unrelated identities.

Implementation is in progress. Unzen runs the startup-gated media system through temporary `switch-to-configuration test` activation. All target application and proxy ready markers remain absent. Yari's five applications, five proxies, and VPN are now stopped. Persistent source startup gates prevent another owner. The stopped capture is complete. The stopped service-state snapshot passes full admission. Complete staging transfer is running through a protected, temporary transport; target ownership has not started. Preserve Yari's original files for rollback. Stop and ask before a reset, incompatible application upgrade, credential replacement, or expanded scope.

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

Read-only inventories confirmed Yari's media GID is `993`. Unzen already assigns `993` to `systemd-coredump`. The target contract selects GID `390`, which the live inventory and current NixOS reserved-ID table do not assign. The move must map media ownership from `993` to `390`, not change the unrelated group. Recheck the target before activation.

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

## Implementation checkpoint

The application packages preserve all five deployed releases. State capture, existing-state startup validation, placement-generated storage, a separate OAuth media proxy, and disposable NFS/WireGuard fixtures are implemented. Target units are activated with startup gates closed. Source owners are stopped and gated; target ownership remains closed during capture and transfer.

Paused verification uses native Transmission startup pause and disables its watch directory. ARR target copies disable download clients, indexer searches/RSS, and completed-download handling. Prowlarr target copies also disable application sync so it cannot re-enable ARR indexers. Protected receipts retain the exact original flags. Client credentials and application users remain unchanged.

NZBGet uses native startup pause tasks and disables scan/feed scheduling during verification. Before stopping the source, admission must recheck that post-processing jobs and force-priority groups are both zero. The corrected read-only probe found two groups, no post-processing jobs, no force-priority groups, and about 115 MB remaining. It reads NZBGet 26's `MaxPriority`; the earlier `Priority` fallback incorrectly treated an absent field as zero. Missing or invalid priority metadata now fails closed. The native-binary fixture saves and reloads an individually unpaused group, then verifies global holds, unchanged queue identity/size, zero downloads, and preserved partial bytes. This is not permission to resume or import either production group.

NZBGet's effective setup includes options supplied by its source unit, not only its configuration file. Preserve the effective staging paths, server settings, and cache/unpack options. Map architecture-dependent WebDir, UnrarCmd, and SevenZipCmd to the corresponding pinned target packages. Do not copy ARM executable paths into an x86 runtime.

The VM adapter consumes the same placement-to-mount contract as real hosts. Its sparse disks satisfy mergerfs's real 10 GB reserve. Bind and mergerfs mounts follow directory setup and network readiness, rather than blocking `local-fs.target`. Tests must reject systemd boot-ordering cycles, not merely pass after systemd discards a dependency job.

Manifest format 2 verifies nanosecond modification times, extended-attribute hashes, named POSIX ACL IDs, and hardlink relationships in addition to bytes, modes, symlinks, and owner mappings. A hardlink outside the captured scope stops capture. The state VM passes 31 normal-user metadata/scope tests, one root native-transfer test, 13 existing-state/ARR-hold tests, three NZBGet tests, one Transmission saved-queue test, and four root-preserving cleanup tests. The native tar/rsync test preserves the private Prowlarr layout, cross-root hardlinks, partial bytes, modes, ownership, nanosecond timestamps, xattrs, and named ACLs. Native rsync owner mappings leave named ACL IDs unchanged. Explicit descriptor-based ACL mapping admits all other metadata before making any changes, rejects unexpected IDs, and verifies the complete result. Default-ACL tests prove mapped inheritance and idempotence. The scope tests permit hardlinks across explicitly selected roots. They reject overlapping roots, symlink parents, escaping paths, duplicate or empty roots, and hardlinks outside the complete scope. Filesystem tests run in a VM because the Nix build sandbox rejects xattr/ACL writes.

Normal-user storage tests exposed two permission failures that root-only tests missed. Squashing every producer-side NFS caller to root changes the owner of new files, so mergerfs rejects timestamp preservation. The new producer export preserves numeric identities with `no_root_squash`; approved client hosts must use the same application UIDs and media GID. This retains root trust for those hosts, but stops granting every ordinary caller root identity. FUSE permission checks remain enabled.

The operator selected a client-side mapped view. Keep Zao's stored ownership and export policy unchanged. Bindfs displays each library entry under the Sonarr or Radarr UID and maps GID 993 to target GID 390. New files created directly through the view use stored UID 0. Existing stored UIDs remain unchanged. Each application uses its own view through its existing pooled library path. Keep `default_permissions`, `chown-deny`, and `chgrp-deny` enabled.

The runtime VM passes creation, exact timestamp preservation, and rename under the Sonarr and Radarr accounts in existing Zao directories. New pooled imports correctly go to staging. Direct creation through the mapped view retains stored UID 0 and GID 993 in the Zao fixture. An existing owner-only file retains its bytes, mode, and stored ownership after a pooled read. Explicit ownership changes fail. The live read-only inventory found stored UIDs 0, 274, 275, and 991. A UID-0-only mapping failed exact timestamp operations on the UID-991 fixture. The revised view passes timestamp-preserving writes and rename for UID-991 files under both application accounts without changing stored ownership or modes.

Stopping the TV view stops a consumer with Sonarr's production dependencies, stops storage readiness, and unmounts the pooled TV path. Restoring readiness permits another import test. These are filesystem and dependency tests, not actual application imports or proof of live Zao access. A network outage can block a hard NFS mount without stopping its systemd unit. Do not treat the mount-stop test as proof that every network failure stops an application.

Both runtime and state checks pass. Runtime evidence is `/nix/store/11hs0ys2s37d5xm398i6gg3fxc93qqnl-vm-test-run-portable-media-runtime`. State evidence is `/nix/store/ccp2rrsq4alik15a2gmf5bjhqyamnh07-vm-test-run-media-state-preservation`, with 53 passing tests. The target contract also passes with mapped views and unchanged production enablement. Live read-only evidence reports 72 directories and 664 files. All use GID 993. Directories use mode 2775 and files use mode 664. The active export table reports `rw,all_squash,anonuid=0,anongid=993`, consistent with the fixture. The kernel export cache alone contained no entries and did not establish the export policy. No Zao ownership or export configuration changed. Live read-only Unzen admission passed under numeric Sonarr UID 274 and Radarr UID 275, both with GID 390. The probe read the first 4,096 bytes of all 636 TV files and 28 movie files through separate read-only mapped views. It used a private mount namespace and left no production mounts or accounts. This proves bounded reads, not complete file hashes or live writes.

The extended, startup-gated Unzen system builds with the mapped views and passed temporary activation. Its current output is `/nix/store/aw9dqhfkmzv4pj1yx32g0936b2wkr2n9-nixos-system-unzen-26.11.20260923.4975466`. The admitted prior baseline is `/nix/store/vh51z1nq1jsmhx113v7y22dwfl38gvjy-nixos-system-unzen-26.11.20260923.4975466`. A read-only SHA-256 comparison found no non-media unit differences. Temporary activation verified all five applications and proxies inactive, all ready markers absent, and unchanged operator UID/GID. The actual target media-proxy UID/GID is `992:989`; map source proxy `995:992` to those actual IDs. Protected deployment evidence is `/var/lib/media-migration/deployment/gated-baseline.json`. The normal system profile and declared host configuration still need durable media placement after admission. Recheck the live system before further activation because another session maintains the runner.

Actual source ARR copies also passed held native startup on Unzen. A private network namespace exposed loopback only. Pinned binaries authenticated with the retained API keys and preserved users, connection settings, database counts, and releases. Sonarr retained 18 series, 623 episode files, 3,779 history rows, two download clients, and one user. Radarr retained 25 movies, 17 movie files, 103 history rows, two download clients, and one user. Prowlarr retained two applications, one indexer, and one user. These were online SQLite backups for admission, not stopped full-state captures.

A fresh read-only transfer-scope probe found 716 staging files containing 142,216,699,883 bytes. It found no hardlinked files in the selected scope. The only symlink is the expected `/var/lib/prowlarr` link to `/var/lib/private/prowlarr`. The physical private directory must accompany that link. No process outside NZBGet, Transmission, and Prowlarr occupied the source VPN namespace during that probe. This does not replace the stopped-writer check.

Existing OAuth credentials passed read-only admission for five unique authorized service registrations. The protected target receipt is `/var/lib/media-migration/deployment/identity-before-bcd0c0ab9baa4ee6a81c41637ef65584.json`. No enrollment or device deletion occurred. The source-native repaired proxy runtime also passed AArch64 ELF validation, static-interpreter admission, and harmless help execution on Yari. Its protected path is `/var/lib/media-migration/rollback-runtime/tsnet-proxy`, with SHA-256 `c4c8da856ca38dff2fbba182e944accd753e48f7e9c424db47588da6a1a97d5e`. The executable-only deployment at `/opt/media-migration/rollback-runtime/tsnet-proxy` also passes help execution as source UID 995 and GID 992 with no supplementary groups. Initial private directory modes blocked that user. Explicit mode 0755 on the newly created code directories fixes access; credential directories retain mode 0700. This proves native execution, not rollback identity recovery.

Read-only source control admission verified the original ARM system, eleven owner units, and exactly three VPN processes belonging only to the moved services. A controlled-move dry run also verified target inactivity, absent ready markers, capacity reserve, operator identity, queue safety, and native source commands. A redundant NZBGet username override is removed only when the saved configuration supplies the exact same value. Other credential overrides fail closed.

The approved stop phase now has all eleven source owners inactive with zero main/control PIDs. `/var/lib/media-migration/retired` closes persistent source drop-ins under `/etc/systemd/system.control/`. Source media mover units and timers are also stopped and gated. The read-only owner checkpoint is `/tmp/media-live-move-checkpoint-4e41fe28e92a4c57b579d331eada90df.json`. Both hosts had zero active media owners at that checkpoint. Source files remain intact. The stopped capture contains 2,022 files and 142,715,778,992 bytes. Its source directory is `/var/lib/media-migration/captures/mountainous-media-inventory-28b04877be654965896dfdee3ce7e65a`.

The original SSH prefetch and control-bundle streams were too slow and have been stopped. Their private partial archives remain retained and unadmitted. Source disk reads are not the bottleneck: the 8 MiB sample reads in 0.007361 seconds. Source SSH metrics show retransmissions. A direct Tailscale path alone did not resolve the throughput problem. The underlying packet-loss cause remains unknown.

A temporary, root-owned read-only snapshot job on Yari serves only the captured scope and four control artifacts over mutually authenticated TLS 1.3. Its certificate expires after one day and its runtime is bounded. Existing SSH keys, application credentials, global networking defaults, and source startup gates remain unchanged. The temporary transfer sockets use BBR. The same 8 MiB sample improved from 77.861 seconds to 1.052 seconds. The complete transfer then delivered 5,369,647,877 wire bytes in 369 seconds. These are measured transport results, not completed full-scope admission.

The current private target is `/var/lib/media-migration/transfer/direct-stopped-28b04877be654965896dfdee3ce7e65a`. `control-received.json` records received control artifacts. `service-source-admitted.json` proves all 1,306 stopped service files and 499,079,109 bytes match original ownership, modes, nanosecond timestamps, xattrs, ACLs, symlinks, hardlinks, and contents. Native archive paths and link targets are checked before extraction. The stopped ARR databases retain the same users and record counts as the earlier copied-state admission.

The complete receiver resumes individual files only against their stopped sizes and SHA-256 values. It restores original metadata inside a root-protected container, then verifies the whole scope before creating `source-admitted.json`. A real TLS fixture proves partial-file resume, corrupt-partial refusal, named/default ACLs, xattrs, timestamps, modes, ownership, absolute symlinks, hardlinks, and scope denial. Target production paths and ready markers remain unchanged. Full staging and ownership-map admission remain required.

Existing admitted OAuth credentials have been delivered to the prepared source rollback paths without replacing existing source credential values. Protected source receipt: `/var/lib/media-migration/rollback-credentials-ready.json`. Source read-only OAuth admission also reads all five unique authorized registrations and their original addresses. It does not start an identity, enroll, or delete a device. The native state VM also passes an inverse transfer after simulated target identity and partial-file writes. It returns those newest bytes, reverses UID/GID and named ACL mappings, and preserves private Prowlarr ownership, symlinks, timestamps, and cross-root hardlinks. It rejects the stale original manifest. Evidence is `/nix/store/mam282qadfqcl69is2dvl23ljydzfwqz-vm-test-run-media-state-preservation`. This proves the native transfer contract, not an actual production rollback or source identity restart.

The agent runs on Zao. Temporary TLS key files generated there have mode 0600 in a mode-0700 directory. An earlier claim that Zao held no transfer keys was incorrect. The attempted Zao ciphertext relay has been stopped. It did not change the library or any persistent service configuration.

Identity recovery, complete transfer admission, current-compatible rollback, and final production-unit startup admission still need verification. Do not activate production on the strength of package or partial VM checks alone.

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

## Authorized cutover procedure

1. Prepare and verify the target with startup gated closed.
2. Record the exact state/work-file transfer scope within the approved five-application move. Ask only if preservation requires a reset, incompatible upgrade, or expanded scope.
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
