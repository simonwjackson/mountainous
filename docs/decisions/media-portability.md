# Controlled media-service moves with local staging

Accepted by the operator on 2026-10-10. Media applications must support separate host placement without resetting application configuration or manually reconfiguring their clients. Unzen is the first target, not a permanent co-location requirement.

Use controlled moves, not automatic failover. Each move preserves service addresses, application state, credentials, and network identity. Only one host owns the active service during the handoff.

Keep staging on the downloader's current host. Other applications receive managed access to its completed files. A downloader move includes its work files. Long-term media remains on Zao for this port.

## Client-side mapped access to the media library

The operator selected a client-side mapped view for existing Zao media. Keep the stored ownership and the export policy on Zao unchanged. Translate legacy ownership only in the view that Sonarr and Radarr use. Do not disable filesystem permission checks or assign the unrelated `systemd-coredump` group to these services.

The cost is an additional filesystem layer on each host with Sonarr, Radarr, or the library mover. Required mounts must stop their consumers on failure. The view does not replace transfer, identity, processing-hold, or rollback admission for a controlled move.

## Trade-offs

| Chosen policy | Rejected alternative | Cost |
| --- | --- | --- |
| Controlled moves preserve state through an explicit handoff. | Automatic failover requires storage recovery and competing-owner controls. | The moved service pauses during the handoff. |
| Local staging keeps downloading and unpacking on the downloader host's disk. | Shared staging avoids copying work files when compute moves. | Downloader moves consume transfer time and bandwidth. Remote ARR access needs managed storage access. |
| Stable service endpoints work across host placement. | Local-only application connections assume co-location. | Cross-host network failures can interrupt imports. |

New service identities use OAuth-backed tagged enrollment with routine node-key expiry disabled. A controlled move retains the existing node ID, keys, owner, and addresses. Do not enroll a saved identity again. OAuth credentials remain revocable.

## Saved identities take precedence over enrollment

The five original media registrations were user-owned and had expired keys. A native recovery test with a tagged OAuth auth key created five duplicate registrations. It retained each machine key but changed the node ID, node key, owner, and address. Retaining a machine key alone does not prove identity recovery.

Read the saved node state before reading enrollment credentials. Tailscale stores this state in the `Config` field of the current profile. With valid saved node state, supply no auth key. Reject corrupt, incomplete, or symlinked saved state before contacting the enrollment API. Reject forced login and inherited `TS_AUTHKEY` for a saved identity. The pinned tsnet library otherwise reads `TS_AUTHKEY` after the runtime supplies an empty auth key.

Recover an expired original registration with a verified, narrowly scoped expiry update. Do not replace its keys, retag it, delete it, or use a duplicate. Native admission must prove the original stable address before production startup.

The cost is that existing service identities retain their original owner. The runtime cannot repair expiry without an authorized control-plane action. Disabling expiry also removes periodic reauthentication for those five keys. A later ownership change needs separate approval and identity-preservation admission.

## Scheduler holds preserve original task state

Pinned ARR releases replace task intervals during startup. They retain existing `ScheduledTasks.LastExecution` values. Disabling clients and indexers alone does not stop scheduled scans, list imports, or cleanup.

A controlled move holds all existing task timestamps at `2099-01-01 00:00:00` before startup. Protected receipts retain each original row. Startup rejects missing scheduler state, queued or active ARR commands, and task timestamps outside this hold. It also refuses startup from 2098 until the operator renews the hold. No command payload is removed or replaced.

The cost is suspension of scheduled backups, health checks, and update checks. The hold does not prevent an authorized user from starting a manual command. Processing resumption requires separate approval and restoration of the retained original flags and task timestamps.

Approval of this design alone does not authorize live cutover, bulk transfer, credential replacement, download resumption, forced imports, or deletion of existing state or media. The operator subsequently approved the controlled move and held deployment. See the [implementation and acceptance plan](../plans/media-portability.md).

## Verified library handoff and staged resumption

The operator selected `finish-and-staged-resumption` in `finish-media-processing`, ask ID `6b3d885b-7be1-4207-9b8a-bcf2dcae69d4`. This approval covers the library mover, notification repairs, one representative production workflow, and staged normal processing after acceptance. It excludes a reboot, application reset, upgrade, credential replacement, original-source cleanup, and messaging relocation.

The library mover publishes verified aged imports through the mapped view. Atomic no-replace publication refuses different destination content. Existing destination metadata remains unchanged. Physical import roots and completed-download hardlinks remain. A protected receipt retains pending Jellyfin refresh work until the existing authenticated connection accepts it.

The cost is one file copy and repeated SHA-256 reads before source release. Retained completed-download hardlinks can prevent this handoff from increasing free space. The mover does not reconstruct missing download history or repair missing archive data. A processing rollback needs a fresh current-state capture after processing advances.

Messaging stayed on Yari during the move. Only the retained ARR webhook host changed from loopback to the existing Yari relay.

On 2026-10-12 the operator retired messaging and deleted its data. The ARR webhook notifications to the relay were removed. The Jellyfin notifications remain. Yari is now a bare server host on `cairn`.
