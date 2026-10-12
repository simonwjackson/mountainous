# Unexpected native processing during imports-only acceptance

## Current state

The operator accepted losing the one original TV episode in ask `b836723a-3413-4c41-abbb-482df9b4be08`. The original bytes are not recovered. This does not authorize any other media loss.

The incident is closed. After the fix below, the representative workflow and staged resumption passed. Normal processing runs on Unzen. See the [plan status](media-portability.md#status-and-scope).

The assistant restored original ARR download-client flags and completed-download handling for imports-only acceptance. The assistant incorrectly assumed that held scheduler timestamps would prevent old completed groups from being processed. Native Sonarr's grab command triggered monitored-download refresh outside that assumption. The original client settings also enabled completed and failed download removal.

## Verified effects

- Native Sonarr approved 23 single missing-episode releases and grabbed one 72,220,000-byte release without an override.
- Native processing consumed retained groups 762 and 763. Their full NZBGet history entries and target staging folders are gone. The full history API still returns their duplicate markers. Their full protected JSON history records and original source captures remain.
- The original episode file record 942 was removed. Its episode now references file record 1548.
- The original media library file was 291,032,801 bytes. The replacement is 290,738,630 bytes.
- The original physical Zao file is absent. The replacement exists in Unzen's physical local import branch at the original union path.
- The original recycle bin configuration was absent.
- The admitted stopped-source file manifest contains no file of the original size.
- Direct read-only Zao checks found no surviving same-path copy, no original-size open deleted handle, and no original-size file among 203,410 physical files.
- Zao's Btrfs subvolume list contains no snapshots. Its media disks are XFS. No filesystem repair, reset, formatting, block recovery, or disk write was performed during the recovery search.

These checks do not prove that no external backup exists. The original file bytes have not been recovered. The operator accepts their loss. Do not describe the replacement as an exact recovery.

## Preservation and evidence

During the incident, all Unzen owners and the mover had persistent `95-unexpected-native-cleanup-hold.conf` gates under `/etc/systemd/system.control/`. Later admitted transitions removed those gates. The marker file `/var/lib/media-migration/unexpected-native-cleanup-hold` remains as a record. No current gate reads it.

Protected Unzen evidence is under `/var/lib/media-migration/`:

| Evidence | Path |
| --- | --- |
| Initial ARR preservation fence | `unexpected-native-cleanup-preservation/42222cc70f424d019ed84487cd8ddc44/admission.json` |
| Current stopped state and queue metadata | `unexpected-native-cleanup-preservation/42222cc70f424d019ed84487cd8ddc44/current-stopped-state-7ef6d1e97ec04f268f394af07396a212/admission.json`. Its `current-state-and-native-queue-tree` retains current state without replay. |
| Verified replacement copy and mover fences | `unexpected-native-cleanup-preservation/42222cc70f424d019ed84487cd8ddc44/replacement-preservation-582d71ad236442b59a2005e49d9114e7/admission.json`. The replacement stays in place and has a content/metadata-verified protected copy. The mover and its timers also have persistent preservation gates. |
| Native removal policy and lost staging directories | `native-client-cleanup-diagnostic/29977393062b417eacca7c52d7ae3465/` |
| Original and current episode records, physical branch checks | `original-episode-recovery-diagnostic/61f3f4aa936d446286f71a952f697521/` |
| Full native history after cleanup | `native-history-retention-diagnostic/634ad74d869b4601a41c48cfd7b78c20/` |
| Approved existing-key binding test | `existing-prowlarr-key-binding-test/c88278203b6c4c0eb619b3478fb37966/admission.json` |
| Native approved release search | `representative-native-sonarr-release-search/975f21c69e104ee79e55884381be55a7/` |

Protected direct Zao checks are at `/tmp/media-zao-original-file-recovery-05f422ce86ef4131a12de83b6c7b18a9/`. The copied original file record is under `/tmp/media-local-original-file-recovery-589dd63a3325483fa7accb586c30f568/`.

The native grab receipt's claim that groups 762 and 763 remained in live history was based on the check before the grab. It did not verify the state after native refresh. That claim is not valid after cleanup.

## Fix and remaining limits

- Imports-only processing now holds automatic completed-download handling and completed/failed removal. Protected receipts in `processing-original-safe/` keep the exact original flags from SHA-256-admitted source databases. Normal processing restores them.
- Enabled startup admits the original flags and lets native task timestamps advance. It refuses a leftover scheduler hold.
- The 42 real SQLite service-state tests cover held imports and removal, exact restoration, enabled startup, and side-effect-free reads. The runtime VM covers NFS, ownership, mount gates, VPN, and refresh failure and retry.
- No native ARR regression grabs a release while old completed and failed groups exist.
- Keep the replacement file and all protected copies. Do not restore an old database or queue over current state.
