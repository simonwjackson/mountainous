# Portable media services: implementation and acceptance plan

## Status and scope

The operator approved [controlled moves and local staging](../decisions/media-portability.md). The operator also approved `migrate-preserving-state`: implementation, tests, deployment, source service stops, protected application/work-file transfers, and paused target startup verification. Downtime is acceptable. Expired service enrollment can be repaired without deleting unrelated identities.

The controlled move is in progress. All five target applications and original stable HTTPS endpoints are restored and held. Current-compatible source rollback admission passes. Unzen's active and normal system profiles now point to the admitted held system. Boot deployment is blocked because GRUB cannot write `/boot/grub`. Read-only inspection reports the mounted boot/root NVMe device at 0 B with I/O errors. No boot repair, disk reset, formatting, or reboot occurred. Do not treat the normal profile update as completed boot deployment.

Yari's five applications, five proxies, and VPN remain stopped. Persistent source startup gates prevent another owner. Current-compatible rollback admission now passes for all 13 state and staging roots. The original native ARM applications and saved identities also pass on private copies of the newest captured target state. These tests do not execute a live source rollback. Source production files and units remain unchanged.

Preserve Yari's original files for rollback. Stop and ask before a reset, incompatible application upgrade, credential replacement, or expanded scope.

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
| Network identity | Preserve valid saved node state before enrollment. New identities use OAuth-backed tagged enrollment only without saved state. Permit only one active owner. |
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

Paused verification uses native Transmission startup pause and disables its watch directory. ARR target copies disable download clients, indexer searches/RSS, and completed-download handling. Prowlarr target copies also disable application sync so it cannot re-enable ARR indexers. Protected receipts retain the exact original flags. ARR holds also freeze native scheduler task timestamps before startup. Client credentials and application users remain unchanged.

NZBGet uses native startup pause tasks and disables scan/feed scheduling during verification. Before stopping the source, admission must recheck that post-processing jobs and force-priority groups are both zero. The corrected read-only probe found two groups, no post-processing jobs, no force-priority groups, and about 115 MB remaining. It reads NZBGet 26's `MaxPriority`; the earlier `Priority` fallback incorrectly treated an absent field as zero. Missing or invalid priority metadata now fails closed. The native-binary fixture saves and reloads an individually unpaused group, then verifies global holds, unchanged queue identity/size, zero downloads, and preserved partial bytes. This is not permission to resume or import either production group.

NZBGet's effective setup includes options supplied by its source unit, not only its configuration file. Preserve the effective staging paths, server settings, and cache/unpack options. Map architecture-dependent WebDir, UnrarCmd, and SevenZipCmd to the corresponding pinned target packages. Do not copy ARM executable paths into an x86 runtime.

The VM adapter consumes the same placement-to-mount contract as real hosts. Its sparse disks satisfy mergerfs's real 10 GB reserve. Bind and mergerfs mounts follow directory setup and network readiness, rather than blocking `local-fs.target`. Tests must reject systemd boot-ordering cycles, not merely pass after systemd discards a dependency job.

Manifest format 2 verifies nanosecond modification times, extended-attribute hashes, named POSIX ACL IDs, and hardlink relationships in addition to bytes, modes, symlinks, and owner mappings. A hardlink outside the captured scope stops capture. The state VM passes 31 normal-user metadata/scope tests, one root native-transfer test, 20 existing-state/ARR-hold tests, three NZBGet tests, one Transmission saved-queue test, and four root-preserving cleanup tests. The native tar/rsync test preserves the private Prowlarr layout, cross-root hardlinks, partial bytes, modes, ownership, nanosecond timestamps, xattrs, and named ACLs. Native rsync owner mappings leave named ACL IDs unchanged. Explicit descriptor-based ACL mapping admits all other metadata before making any changes, rejects unexpected IDs, and verifies the complete result. Default-ACL tests prove mapped inheritance and idempotence. The scope tests permit hardlinks across explicitly selected roots. They reject overlapping roots, symlink parents, escaping paths, duplicate or empty roots, and hardlinks outside the complete scope. Filesystem tests run in a VM because the Nix build sandbox rejects xattr/ACL writes.

Normal-user storage tests exposed two permission failures that root-only tests missed. Squashing every producer-side NFS caller to root changes the owner of new files, so mergerfs rejects timestamp preservation. The new producer export preserves numeric identities with `no_root_squash`; approved client hosts must use the same application UIDs and media GID. This retains root trust for those hosts, but stops granting every ordinary caller root identity. FUSE permission checks remain enabled.

The operator selected a client-side mapped view. Keep Zao's stored ownership and export policy unchanged. Bindfs displays each library entry under the Sonarr or Radarr UID and maps GID 993 to target GID 390. New files created directly through the view use stored UID 0. Existing stored UIDs remain unchanged. Each application uses its own view through its existing pooled library path. Keep `default_permissions`, `chown-deny`, and `chgrp-deny` enabled.

The runtime VM passes creation, exact timestamp preservation, and rename under the Sonarr and Radarr accounts in existing Zao directories. New pooled imports correctly go to staging. Direct creation through the mapped view retains stored UID 0 and GID 993 in the Zao fixture. An existing owner-only file retains its bytes, mode, and stored ownership after a pooled read. Explicit ownership changes fail. The live read-only inventory found stored UIDs 0, 274, 275, and 991. A UID-0-only mapping failed exact timestamp operations on the UID-991 fixture. The revised view passes timestamp-preserving writes and rename for UID-991 files under both application accounts without changing stored ownership or modes.

Stopping the TV view stops a consumer with Sonarr's production dependencies, stops storage readiness, and unmounts the pooled TV path. Restoring readiness permits another import test. These are filesystem and dependency tests, not actual application imports or proof of live Zao access. A network outage can block a hard NFS mount without stopping its systemd unit. Do not treat the mount-stop test as proof that every network failure stops an application.

Both runtime and state checks pass. Runtime evidence is `/nix/store/11hs0ys2s37d5xm398i6gg3fxc93qqnl-vm-test-run-portable-media-runtime`. State evidence is `/nix/store/ccp2rrsq4alik15a2gmf5bjhqyamnh07-vm-test-run-media-state-preservation`, with 53 passing tests. The target contract also passes with mapped views and unchanged production enablement. Live read-only evidence reports 72 directories and 664 files. All use GID 993. Directories use mode 2775 and files use mode 664. The active export table reports `rw,all_squash,anonuid=0,anongid=993`, consistent with the fixture. The kernel export cache alone contained no entries and did not establish the export policy. No Zao ownership or export configuration changed. Live read-only Unzen admission passed under numeric Sonarr UID 274 and Radarr UID 275, both with GID 390. The probe read the first 4,096 bytes of all 636 TV files and 28 movie files through separate read-only mapped views. It used a private mount namespace and left no production mounts or accounts. This proves bounded reads, not complete file hashes or live writes.

The extended, startup-gated Unzen system builds with the mapped views and passed temporary activation. Its current output is `/nix/store/aw9dqhfkmzv4pj1yx32g0936b2wkr2n9-nixos-system-unzen-26.11.20260923.4975466`. The admitted prior baseline is `/nix/store/vh51z1nq1jsmhx113v7y22dwfl38gvjy-nixos-system-unzen-26.11.20260923.4975466`. A read-only SHA-256 comparison found no non-media unit differences. Temporary activation verified all five applications and proxies inactive, all ready markers absent, and unchanged operator UID/GID. The actual target media-proxy UID/GID is `992:989`; map source proxy `995:992` to those actual IDs. Protected deployment evidence is `/var/lib/media-migration/deployment/gated-baseline.json`. The declared host now includes the three media runtime layers and a held `media-placement-unzen` profile. Its build passes at `/nix/store/a2xwn1dvvvb87lnlpyhg1v4fa3x4g86y-nixos-system-unzen-26.11.20260923.4975466`. The normal system profile remains unchanged until full admission. The real host contract verifies all five preserved releases, all startup gates, held processing, native downloader holds, and independent placement. All media unit bytes match the previously admitted temporary system output. Four non-media unit entries differ only through generated restart-trigger references. Actual comparison found identical contents for all 19,147 package leaves, identical DBus configuration after substituting the verified system-path reference, and identical tmpfiles rules with identical first-rule selection. Activation can still reload these global services. Recheck live state and active units before changing the system profile. Recheck the live system before further activation because another session maintains the runner.

Actual source ARR copies also passed held native startup on Unzen. A private network namespace exposed loopback only. Pinned binaries authenticated with the retained API keys and preserved users, connection settings, database counts, and releases. Sonarr retained 18 series, 623 episode files, 3,779 history rows, two download clients, and one user. Radarr retained 25 movies, 17 movie files, 103 history rows, two download clients, and one user. Prowlarr retained two applications, one indexer, and one user. These were online SQLite backups for admission, not stopped full-state captures.

A fresh read-only transfer-scope probe found 716 staging files containing 142,216,699,883 bytes. It found no hardlinked files in the selected scope. The only symlink is the expected `/var/lib/prowlarr` link to `/var/lib/private/prowlarr`. The physical private directory must accompany that link. No process outside NZBGet, Transmission, and Prowlarr occupied the source VPN namespace during that probe. This does not replace the stopped-writer check.

Existing OAuth credentials passed read-only admission for five unique authorized service registrations. The protected target receipt is `/var/lib/media-migration/deployment/identity-before-bcd0c0ab9baa4ee6a81c41637ef65584.json`. No enrollment or device deletion occurred. The source-native repaired proxy runtime also passed AArch64 ELF validation, static-interpreter admission, and harmless help execution on Yari. Its protected path is `/var/lib/media-migration/rollback-runtime/tsnet-proxy`, with SHA-256 `c4c8da856ca38dff2fbba182e944accd753e48f7e9c424db47588da6a1a97d5e`. The executable-only deployment at `/opt/media-migration/rollback-runtime/tsnet-proxy` also passes help execution as source UID 995 and GID 992 with no supplementary groups. Initial private directory modes blocked that user. Explicit mode 0755 on the newly created code directories fixes access; credential directories retain mode 0700. This proves native execution, not rollback identity recovery.

Read-only source control admission verified the original ARM system, eleven owner units, and exactly three VPN processes belonging only to the moved services. A controlled-move dry run also verified target inactivity, absent ready markers, capacity reserve, operator identity, queue safety, and native source commands. A redundant NZBGet username override is removed only when the saved configuration supplies the exact same value. Other credential overrides fail closed.

The approved stop phase now has all eleven source owners inactive with zero main/control PIDs. `/var/lib/media-migration/retired` closes persistent source drop-ins under `/etc/systemd/system.control/`. Source media mover units and timers are also stopped and gated. The read-only owner checkpoint is `/tmp/media-live-move-checkpoint-4e41fe28e92a4c57b579d331eada90df.json`. Both hosts had zero active media owners at that checkpoint. Source files remain intact. The stopped capture contains 2,022 files and 142,715,778,992 bytes. Its source directory is `/var/lib/media-migration/captures/mountainous-media-inventory-28b04877be654965896dfdee3ce7e65a`.

The original SSH prefetch and control-bundle streams were too slow and have been stopped. Their private partial archives remain retained and unadmitted. Source disk reads are not the bottleneck: the 8 MiB sample reads in 0.007361 seconds. Source SSH metrics show retransmissions. A direct Tailscale path alone did not resolve the throughput problem. The underlying packet-loss cause remains unknown.

A temporary, root-owned read-only snapshot job on Yari serves only the captured scope and four control artifacts over mutually authenticated TLS 1.3. Its certificate expires after one day and its runtime is bounded. Existing SSH keys, application credentials, global networking defaults, and source startup gates remain unchanged. The temporary transfer sockets use BBR. The same 8 MiB sample improved from 77.861 seconds to 1.052 seconds. The complete transfer then delivered 5,369,647,877 wire bytes in 369 seconds. These are measured transport results, not completed full-scope admission.

The operator requested chunked parallel transfer. Isolated 64 MiB samples measured 3,998,938 B/s with one stream, 17,499,667 B/s with two, and 20,817,707 B/s with four. Reassembled sample hashes match. The serial receiver was temporarily paused and resumed for the isolated comparison. A 180-second watchdog bounded that pause. Short samples do not prove sustained bulk speed.

Six real TLS chunk tests pass. They verify an existing prefix, partial cached-chunk resume, complete cached-chunk reuse, gap-free bounded ranges, corrupt-prefix and corrupt-cache refusal, symlink and external-hardlink refusal, and source scope denial. The real four-worker metadata integration also passes original bytes, ownership, modes, nanosecond timestamps, xattrs, named/default ACLs, symlinks, and cross-root hardlinks.

The serial managed transfer and its unique native target writer are now stopped. The protected handoff receipt reports 59,443,652,637 retained file bytes. The replacement uses four workers and 64 MiB chunks over the same mutually authenticated endpoint. Only its coordinator appends the ordered chunks to each existing prefix. Every complete file must match its stopped SHA-256 before metadata restoration and full-scope admission. A duplicate-writer guard rejects another native receiver. No application or identity starts during this handoff.

The fixed-chunk receiver has since stopped for a guarded handoff. It retained 72,565,243,933 file bytes. The replacement keeps four worker threads and reuses their actual TLS sockets across files. It selects smaller chunks for files below 256 MiB, with a 16 MiB minimum and a 64 MiB maximum. This gives the common 105,216,000-byte parts four requests instead of two. File-prefix resume and final stopped-file SHA-256 verification remain mandatory. Existing chunk-cache files remain retained, although changed range boundaries do not reuse every old cached range.

Seven real TLS tests pass, including reuse of the same socket objects across two source files. The complete native-metadata fixture also passes. A bounded production-path sample copied two complete 105,216,000-byte stopped files for each case. One persistent stream measured 11,814,044 B/s. Four measured 16,437,675 B/s. Every file matched its stopped SHA-256. The existing bulk receiver was paused only during this sample and resumed with a watchdog. This is a bounded comparison, not proof of sustained speed. The adaptive receiver is running; full-scope admission remains pending. Source retirement and target startup gates remain closed.

Chunk files remain outside the captured tree, under the protected container's `chunk-cache/`. They retain partial progress and cost extra local writes, reads, and disk space. Source application files, endpoint identities, source retirement gates, target production paths, and startup markers stay unchanged.

The current private target is `/var/lib/media-migration/transfer/direct-stopped-28b04877be654965896dfdee3ce7e65a`. `control-received.json` records received control artifacts. `service-source-admitted.json` proves all 1,306 stopped service files and 499,079,109 bytes match original ownership, modes, nanosecond timestamps, xattrs, ACLs, symlinks, hardlinks, and contents. Native archive paths and link targets are checked before extraction. The stopped ARR databases retain the same users and record counts as the earlier copied-state admission.

The complete receiver resumes individual files only against their stopped sizes and SHA-256 values. It restores original metadata inside a root-protected container, then verifies the whole scope before creating `source-admitted.json`. A real TLS fixture proves partial-file resume, corrupt-partial refusal, named/default ACLs, xattrs, timestamps, modes, ownership, absolute symlinks, hardlinks, and scope denial. Target production paths and ready markers remain unchanged. Full staging and ownership-map admission remain required. Read-only publication-layout admission finds all thirteen production roots on the same filesystem as the protected snapshot, with no existing files and no mounts at or below those roots. A disposable native 13-root publication test passes complete metadata, cross-root hardlinks, the private Prowlarr symlink, private-parent protection, unrelated-state retention, and idempotence. It uses explicit roots and `--no-implied-dirs`, without deletion. No production files have been published.

Existing admitted OAuth credentials have been delivered to the prepared source rollback paths without replacing existing source credential values. Protected source receipt: `/var/lib/media-migration/rollback-credentials-ready.json`. Source read-only OAuth admission also reads all five unique authorized registrations and their original addresses. It does not start an identity, enroll, or delete a device. The native state VM also passes an inverse transfer after simulated target identity and partial-file writes. It returns those newest bytes, reverses UID/GID and named ACL mappings, and preserves private Prowlarr ownership, symlinks, timestamps, and cross-root hardlinks. It rejects the stale original manifest. Evidence is `/nix/store/mam282qadfqcl69is2dvl23ljydzfwqz-vm-test-run-media-state-preservation`. This proves the native transfer contract, not an actual production rollback or source identity restart. A later read-only source probe admits the actual five rollback proxy units: repaired native command, protected credential delivery, saved identity, UID/GID 995:992, and persistent retirement conditions. All eleven source owner units remain inactive. Native help still executes under the real source proxy UID/GID without supplementary groups. No identity starts in that probe.

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
| Identity recovery | Recover an expired original registration with its saved node keys and an authorized expiry update. New identities use OAuth enrollment only when no saved identity exists. Corrupt saved state fails closed. No credential disclosure or unrelated device deletion occurs. |
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

## Verified checkpoint after the 2026-10-11 reboot

Unzen booted its previous normal profile. All 14 persistent reboot gates survived. The six saved admission receipts were unchanged, and both protected recovery trees were present. Reapplied the admitted temporary configuration with `test` only. The normal boot profile remains unchanged, and every media owner remains stopped.

Native OpenSSL derivation proved that all five original saved node keys and machine keys still match the original registrations. The tagged enrollment test changed their owner and created duplicates. Do not use those duplicates as recovery state.

Disabled expiry on the five verified original registrations through the existing OAuth authorization. Node IDs, keys, owners, tags, and addresses were unchanged. A private copy of the original `tv` identity then served at `100.115.156.31` as source UID/GID `995:992`, without an enrollment credential. The probe stopped, and no production source state changed.

All five original identities also passed private native Unzen HTTPS and DNS admission as UID/GID `992:989`. Original addresses, node IDs, keys, and owners remained unchanged. No enrollment credential was delivered, and no registration was added or deleted. Each probe returned the expected backend-unavailable response, then stopped. This proves identity and TLS recovery, not application health or production handoff.

The repaired system passed temporary `test` activation with every production gate closed. Only the five proxy executable paths differed from the previous admitted durable build. The normal system profile remained unchanged. Protected receipts include `target-original-native-identities-3970d063977c42a4afa0c6259e34479f/admission.json` and `deployment/repaired-held-test-8e434f9649c841babef4f6c44be675d6.json` below `/var/lib/media-migration`.

## Native scheduler-hold admission on 2026-10-11

Client and indexer flags alone did not establish a scan hold. The pinned [Sonarr TaskManager](https://github.com/Sonarr/Sonarr/blob/v4.0.16.2944/src/NzbDrone.Core/Jobs/TaskManager.cs), [Radarr TaskManager](https://github.com/Radarr/Radarr/blob/v6.0.4.10291/src/NzbDrone.Core/Jobs/TaskManager.cs), and [Prowlarr TaskManager](https://github.com/Prowlarr/Prowlarr/blob/v2.3.0.5236/src/NzbDrone.Core/Jobs/TaskManager.cs) retain task timestamps but replace intervals during startup. The hold therefore changes only `ScheduledTasks.LastExecution`, with protected original rows for later approved resumption.

Matching native binaries started private stopped-state copies with loopback-only networking, hidden library and staging paths, and hidden host runtime sockets. All 30 scheduled rows remained held throughout 65 seconds after readiness. Sonarr and Radarr each retained 11 rows. Prowlarr retained eight. Queued and active command counts stayed zero. Users, API keys, client configurations, and all selected record counts, including history, stayed unchanged.

Protected native receipt: `/var/lib/media-migration/native-arr-scheduler-proof-9a7d3f2c90c047028d8cd9ff7b34b1cb/admission.json`. The validated hold now applies to the private candidate. `scheduler-held-candidate-scope.json` and `scheduler-held-candidate-admitted.json` record that phase. Original captures, prior admission receipts, processing flags, and task rows remain retained. No staging file, identity, or production path changed in this operation.

Regression tests rejected the old flags-only gate and queued-command behavior before the repair. The updated state VM and proxy package checks pass. The proxy also rejects inherited `TS_AUTHKEY`, which the pinned tsnet library otherwise reads after receiving an empty auth key. At that checkpoint, full native publication, application startup, live VPN admission, durable activation, and current-compatible production rollback remained unfinished. All production owners were stopped.

## Production publication and held ARR startup on 2026-10-11

Published exactly the 13 approved roots. Full candidate and production admission checked all captured bytes and metadata, including staging, numeric mappings, hardlinks, and the private Prowlarr layout. Existing root parents remained unchanged. Source files and protected recovery copies remain retained. Protected receipt: `/var/lib/media-migration/publication/d7807c9be3454926a4fe1b5ea729f576/admission.json`.

The preserved target VPN passed a recent native handshake, HTTPS egress, and default-route admission. No IPv4 default route used an ordinary host route. Protected receipt: `/var/lib/media-migration/vpn-admission/06095de2c9294dc6bf41bb59f3667c8c/admission.json`. The repaired ARM proxy also served all five original identities from private source copies without enrollment credentials. All private probes stopped. This proves the source proxy protocol, not complete current-state production rollback.

Actual ARR startup exposed a missing mount dependency. The runtime bound storage readiness to mount units for local completed directories. Those directories are not mounts. The repair retains `RequiresMountsFor` for their backing filesystems and binds only real managed mounts. Contract tests failed before the repair and passed afterward. A four-host runtime VM passed local staging startup, remote completed-file access, mapped library access, mount-loss stops, missing-state gates, and WireGuard tunnel-loss checks. Only `media-storage-ready.service` changed among 461 declared unit paths. Scheduler gates, binaries, and other unit contents stayed unchanged.

The repaired system passed temporary activation. The normal profile remained unchanged, three critical baseline services stayed active, and the admitted VPN stayed active. Actual Sonarr, Radarr, and Prowlarr then passed their native APIs with the original releases, accounts, API keys, connections, and record counts. All 30 scheduled rows remained held. No queued or started command appeared during 65 seconds after API readiness. Protected receipt: `/var/lib/media-migration/live-held-arr/4b2cbeafa827429dbac8d656b04c121d/admission.json`.

Actual NZBGet and Transmission also passed native RPC admission inside the VPN namespace. NZBGet retained two groups, held download, post-processing, and scanning, and had no force priority or active post/URL jobs. Every retained Transmission torrent was stopped. Both queues stayed unchanged during a further 10 seconds. Credentials and staging settings remained unchanged. Protected receipt: `/var/lib/media-migration/live-held-downloaders/29204e18be814e759e47348e33766e1c/admission.json`.

These separate startup checks did not prove that all five applications stayed active together. A later VPN restart stopped Prowlarr through its namespace dependency. Four applications remained active and held. Native identity incorporation refused before any production identity write because Prowlarr was inactive.

## Actual namespace recovery on 2026-10-11

The namespace service now wants only its local Prowlarr, NZBGet, and Transmission consumers. Their existing state, readiness, processing, and namespace conditions remain unchanged. This restarts admitted services on the same placement. It does not choose another placement or permit two owners. The cost is that a VPN restart also attempts to start each local consumer. Closed readiness gates still refuse startup.

Contract tests rejected the missing consumer dependencies before the repair. The four-host runtime VM passed closed-gate refusal, real tunnel startup, namespace-bound consumer stops, and automatic consumer restart. Its sleeping Prowlarr fixture tests dependency behavior, not application state. Existing state checks remain covered by the preservation VM. The first recovery VM attempt correctly refused the fixture because its required state files were absent. The corrected fixture retained those file conditions.

Checked all 461 declared unit paths against the preceding admitted system. Only the contents of `media-vpn.service` and its existing startup link changed. The only added unit dependencies were its three local consumers. Test activation kept all application and proxy gates closed, retained the admitted VPN, and left the normal profile unchanged. Protected receipt: `/var/lib/media-migration/deployment/vpn-recovery-held-test-7771d4e5889748c78b3b6d4ec897b3d1.json`.

Repeated actual held application startup. A controlled restart of the actual VPN then restored all three namespace consumers without a separate application start command. All five native APIs passed. Original versions, users, API keys, connections, and selected counts remained unchanged. Both downloader queues remained held. Retained torrent counts and partial-byte totals stayed unchanged. All 30 scheduler rows remained held, with no queued or started ARR commands during 65 seconds after readiness. Protected receipt: `/var/lib/media-migration/live-vpn-consumer-recovery/e95de582825146369f3a40a6907fc3fa/admission.json`.

All five applications remained held after that admission. Proxy gates remained closed until separate identity-state and endpoint admission.

## Actual stable endpoint handoff on 2026-10-11

Incorporated all five admitted native target identity states. Each retained the original node ID, node key, and machine key. Protected copies retain the preceding production files and the native private probe files. The helper admitted all five identities and recovery copies before any production write. Protected receipt: `/var/lib/media-migration/identity-handoff/76f2959afea4456e8009cf007964ae8a/admission.json`.

Opened only the five proxy gates after another source-owner fence check. All five actual stable DNS names and original addresses passed native HTTPS API admission. Accounts, API keys, connections, pinned releases, queues, and selected record counts remained unchanged. Original identity owners, keys, tags, addresses, and registrations remained unchanged. No registration was added or removed. Both downloaders remained paused. All 30 scheduled rows remained held, with no queued or started ARR commands during a further 65 seconds. Protected receipt: `/var/lib/media-migration/live-endpoint-handoff/fdf82fc41e404d5ebabb8089badbd73f/admission.json`.

These endpoints passed before the current rollback capture. The capture deliberately stopped and fenced target application and proxy owners. Historical endpoint receipts do not establish current running state. The normal profile remains unchanged until restoration and durable activation pass. Downloads, imports, scanning, post-processing, and sync remain held.

## Current-compatible source rollback admission

Captured the newest stopped target state after actual endpoint admission. Full contents and metadata passed for all 13 approved roots. A protected backup retains the 12 service-state roots. Full actual source staging hashes and metadata then passed comparison against the newest inverse-mapped target scope. No files, bytes, ownership, modes, ACLs, or links differed. Seven directory modification times differed. A protected overlay records those times without changing original source staging.

The complete inverse-mapped source scope passed with the newest service state and staging overlay. Original native ARM applications passed on private working copies. All selected users, keys, connections, counts, queues, and partial-byte totals remained unchanged. All 30 schedules remained held. The applications had no public network route. Original source prestarts did not run. Private namespace parents require mode 0755 so service UIDs can reach read-only staging. NZBGet also requires its declared source-unit options and a private writable queue copy. Missing options and inaccessible private parents caused earlier proof failures. The corrected proof retained the same queue contract.

All five newest saved identity states also passed native ARM HTTPS admission as UID/GID 995:992. Target identity owners remained stopped during the probes. Original registrations, owners, addresses, and keys remained unchanged. All probes stopped. No enrollment credentials were delivered. This proves private identity recovery, not live source rollback.

Sealed source startup artifacts pass native systemd syntax verification. They exclude legacy application bootstrap prestarts and the library ownership normalizer. They retain source numeric identities, native processing holds, existing-state checks, and the admitted saved-identity proxy. The source interpreter has a GC root. The existing source units and retirement gates remain unchanged. Live rollback requires stopping and fencing target owners first, publishing the newest admitted source state and staging overlay, then applying these sealed artifacts. Never restart stale original source state or invoke legacy prestarts blindly.

Protected receipts below `/var/lib/media-migration` include:

- Target capture: `current-compatible-rollback-capture/142b8ac4d1a243dca54dd747556602ae/admission.json`.
- Full current source scope: `current-compatible-source-rollback/ebc8041d9255444d8bd471892722fff7/full-state-admission.json`.
- Native ARM applications: `current-native-source-app-admission/7edfa9fa5633445cae1ce5ff511e8b3f/admission.json`.
- Native ARM identities: `current-source-native-identities-b6f7bd8e39e548a79d0058cb8c077ac3/admission.json`.
- Sealed source startup: `current-compatible-source-rollback/ebc8041d9255444d8bd471892722fff7/safe-startup-admission.json`.

Target restoration uses its current production state. It does not replay original publication. Saved readiness bytes and metadata come from the newest capture.

## Restored held runtime and boot deployment blocker

Actual ARR restoration passes original versions, users, keys, connections, and selected counts. All 30 schedules remain held. Both actual downloader queues pass retained-state and native-pause admission. Repeated actual VPN restart recovery restores Prowlarr, NZBGet, and Transmission automatically. All five actual stable HTTPS endpoints then pass again without identity or credential replacement. Source retirement remains closed.

The current flake evaluates to the exact admitted active system: `/nix/store/z3h24xzx6y002383as684cikyibrlcmj-nixos-system-unzen-26.11.20260923.4975466`. Installed that system as the normal profile. Removed only the exact temporary target reboot marker and its remaining undefined legacy-unit gate. Persistent application/VPN readiness and declared processing holds remain. The bootloader stage of `switch-to-configuration switch` failed before complete deployment. Its exact signal is `mkdir /boot/grub: Input/output error`. All ten target application and proxy units remain active.

Read-only inspection identifies `/boot` as VFAT on `/dev/nvme2n1p1`. GRUB, EFI, and loader directories are not accessible through this mount. `fsck.fat -n` also reports I/O failure. The current firmware boot entry references that partition. `lsblk` reports the parent `nvme2n1` at 0 B. Its second partition belongs to the mounted bcachefs root filesystem. Kernel logs report failed FAT directory reads. The cause of the NVMe loss and the root filesystem's current redundancy are not established. Do not repair FAT or reset a controller on this evidence alone. Do not reboot Unzen.

Final read-only runtime admission still passes the native VPN handshake, tunnel-only IPv4 default routes, and actual consumer namespace membership. Sonarr UID 274 and Radarr UID 275, both using GID 390, read all 636 TV and 28 movie files through the actual mapped views. No library or staging writes occurred. Zao ownership and export policy remain unchanged.

Protected receipts below `/var/lib/media-migration` include:

- Restored ARR: `live-held-arr/7c8c6f510e3040fdaf57411371c1812e/admission.json`.
- Repeated namespace recovery: `live-vpn-consumer-recovery/44ab46b1e4db470b8eba7ff4a01ebd4f/admission.json`.
- Restored actual endpoints: `live-endpoint-handoff/92fe883064ca4bab894596c28338b5b5/admission.json`.
- Partial profile deployment logs: `deployment/durable-held-current-2d6792467f6f4a4984ddad0f5310dfce/`.
- Final VPN/library reads: `final-held-runtime/e6c8c78439934c8aa9e88a1045b0209d/admission.json`.
- Boot read-only inspection: `boot-read-only-diagnostic/10da0da7a8bd4e1eb312602420ff7ee6/admission.json`.
- Read-only FAT/firmware inspection: `boot-read-only-diagnostic/c4ffd8870ffb4317b2381cb14a08a4e1/admission.json`.

Source original files, newest protected recovery state, and source retirement gates remain retained. Processing remains held. Boot/controller recovery requires a separate decision because the unavailable device also contains root filesystem data. Stable endpoint success does not resolve this boot or storage risk.
