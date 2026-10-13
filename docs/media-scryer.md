# Scryer held trial and rollback

Unzen remains `mountainous.features.media-applications.library = "arr"`.
This change does not deploy or migrate production data.
Scryer is pinned to nix-extras main and uses that input's own nixpkgs/cache identity.
In a reused Scryer state, turn acquisition off before a `both` trial. Read-only mounts
prevent library writes, but they do not prevent download-client RPC requests.

## Modes

| `library` | Managers | Scryer filesystem access | Public identities |
|---|---|---|---|
| `arr` (default) | Sonarr, Radarr | No Scryer unit | Existing `tv`, `movies` |
| `both` | Sonarr, Radarr, Scryer | Library roots, basin media, bindfs view and Zao mount read-only; completed downloads not writable | Existing `tv`, `movies`; optional `library` |
| `scryer` | Scryer | Library roots and tv/movie branches writable; only NZBFAST's completion root and Transmission's completed root writable | No `tv`/`movies` proxy; optional `library` |

`mountainous.features.media-applications.scryerTailnet` defaults to `false`.
Set it to `true` only after provisioning and checking authentication.
It publishes `library` to `127.0.0.1:8080` only in `both` or `scryer`.
It does not redirect the saved `tv` or `movies` identities.
The explicit flag permits first OAuth enrollment of the new `library` identity.
The proxy requires ready Scryer; existing ARR proxies still require saved identity state.
Existing identity state stays on disk in every mode.

Scryer runs outside the VPN as UID 392, group media (390), umask 0002.
Prowlarr and the downloaders stay in their existing VPN namespace.
The bindfs force-user values remain 274 (tv) and 275 (movies).
The `@993/@390` mapping does not change in any mode.
Library mounts and `media-storage-ready` gate Scryer as they gate Sonarr.
In `both`, `MountFlags=private` blocks late host mounts from entering Scryer's
namespace. `/srv/media-access` is inaccessible in `both` and `scryer`.
Scryer requires all five library mounts and starts after them. `BindsTo` stops it
on mount loss; `PartOf` propagates an explicit mount restart to Scryer. The restart
creates a new namespace after the mount, rather than retaining a dead FUSE view.
A separate stop/start is not a systemd restart transaction: explicitly start Scryer
after restoring a mount that the operator stopped separately.

## Provisioning order

Commands carry Python and plugins in the system closure. They need root, not nix-shell.
They print fixed errors rather than API bodies or credentials.
Do not put a password or API key in Nix, a command argument, or an environment variable.

1. Keep acquisition and upgrades off through the end of all cutover checks. Freeze the source catalog and library during acceptance.
   Use the approved holds for ARR processing, downloader imports and mover timers
   during the snapshot window. `both` deliberately does not change these services.
   Take application-state backups through the existing media state procedure.
2. Run `media-arr-archive /var/lib/media-migration/arr-archive-YYYYMMDD`.
   The destination must not exist. It contains root-only JSON.
3. Run `media-library-snapshot create /var/lib/media-migration/library-before.json`.
   The destination must not exist.
4. Select `library = "both"` for the approved trial rebuild. Do not enable the tailnet identity yet.
   Scryer will not start without its gate marker and a non-empty password file.
5. Run `media-scryer-provision --open-gate`. This creates the random password file
   with root ownership and mode 0600. Without `--open-gate`, it never opens the gate.
   An absent/not-ready service returns a preparation status; run the command again after start.
6. Run `systemctl start scryer`. Startup admits an empty state directory, or a
   non-empty directory with a readable regular `scryer.db`. Other state is refused.
   SMG enrollment can fail offline; it must not block service startup.
7. Run `media-scryer-provision --plugins` after readiness.
   First login replaces Scryer's temporary bootstrap password through
   `completeRequiredPasswordChange`. It stores the replacement in the same protected
   password file. The command fsyncs each secret file and its parent directory.
   It publishes `.pending` durably before changing the server password, publishes
   the replacement durably before removing `.pending`, and fsyncs the removal.
   Recovery tries both stored passwords, even if the saved API key remains valid.
   Bootstrap creation is durable before the command opens the gate.
   The command saves a non-expiring `mountainous` API key in root-only `scryer.json`.
   Repeated runs reuse a valid key.
8. Confirm renaming is disabled in the source naming configuration before importing.
   Scryer's finalizer can auto-apply source naming and permissions. The command
   fails if finalization changes its protected settings; it does not silently repair them.
9. Run `media-scryer-import`. It validates both local ARR connections, warms them,
   polls, previews, and finalizes same-path SERIES/MOVIE root mappings.
   **Finalization alone does not populate the catalog.** The command follows the
   upstream wizard with hinted `scanLibrary` calls, then polls those scans.
   Before scans apply monitoring, it creates every missing TMDb/TVDb title through
   metadata-only `addTitle`, with the source monitored flag, library root and
   quality profile. This covers titles with no files, not just scanned folders.
   It waits for source seasons/episodes to exist before monitoring consumes its
   snapshot. Metadata hydration needs SMG; a timeout refuses acceptance.
   It never calls `executeExternalImport` or `addTitleAndQueueDownload`, and supplies
   no source hint or search-on-add flag. `addTitle` stores a catalog row, schedules
   metadata hydration and creates no library directories. Acquisition remains off.
   The held-import guard runs before and after finalize, metadata adds and scans.
   It checks expected roots, `HARDLINK_OR_COPY`, renaming/recycle off, acquisition
   off, subtitle download/sync off, plugin auto-update off and **every** quality
   profile's upgrades off. Effective library settings and overrides must not enable
   move imports, NFO/Plex writes, chmod/chown or upgrades. Extra roots are refused.
   It adds the two named Radarr exclusions and applies title-level profile overrides.
10. Run `media-scryer-parity`. Every source title ID, monitoring flag (title, season,
    episode), source file path and effective quality-profile name must match.
    It prints counts and at most 20 mismatches. Any mismatch exits non-zero.
11. Run `media-library-snapshot create /var/lib/media-migration/library-after.json`,
    then `media-library-snapshot compare /var/lib/media-migration/library-before.json /var/lib/media-migration/library-after.json`.
    Dot directories and symlinks are included. Symlinks are not followed.
    New entries are listed; removal of an empty directory is a warning.
    Only the associated parent-directory size/mtime change is tolerated for these
    two allowed changes. All other metadata changes and missing entries fail.
    A `.scryer-recycle` with any content fails even if that content is new.
12. Run `media-scryer-indexer-audit` and `media-vpn-leak-audit`. It checks the expected services for the mode.
    Every Scryer indexer must point to `10.200.200.2:9696`, `indexers`, or
    `indexers.hummingbird-lake.ts.net`. URL host/port matching is strict.
    A missing protected Scryer identity produces an explicit SKIP, not proof of safety.
13. Only after operator acceptance, select `library = "scryer"`.
    Configure Prowlarr/download-client connections and remove-completed routing through
    Scryer's authenticated settings. Client connections are **not** copied by this importer.
    Verify routing and the leak audit before `media-scryer-provision --acquisition on`.
    The normal provision command switches acquisition and upgrades back off.
    Only after all cutover checks pass, explicitly restore upgrades with
    `media-scryer-provision --upgrades match-source --source-archive /var/lib/media-migration/arr-archive-YYYYMMDD`.
    Omit `--source-archive` to read the live Sonarr/Radarr qualityprofile APIs instead.
    Add `--acquisition on` only when acquisition is also approved. A profile name
    with conflicting source `upgradeAllowed` values is refused, not guessed.

All three scopes (MOVIE, SERIES, ANIME) use `HARDLINK_OR_COPY` and renaming off.
MOVIE uses `/srv/range/media/movies`; SERIES uses `/srv/range/media/tv`.
ANIME uses the nested root `/srv/range/media/tv/anime`. Scryer refuses two libraries
with the same root (`crates/scryer-application/src/library/library.rs:487–540`).
Provisioning records that nested path; it does not create or move an anime directory.
The ARR import maps all Sonarr roots to SERIES as requested.
The recycle bin, subtitles (including auto-download and sync), and plugin auto-update are off.
The NZBFAST basin completion path and the mergerfs destination are different
mounts. `HARDLINK_OR_COPY` can therefore fall back to copy (including EXDEV).
Scryer has read/write access to the completion root and all library tv/movie
branches in writer mode. It can publish and verify the copy before remove-completed;
it does not need the incoming or incomplete download trees.
The downloaded plugins are Transmission 2.0.2 and Jellyfin 1.1.1.

## Quality mapping limits

| ARR profile name | Ordered Scryer resolution tiers |
|---|---|
| Any | 4320P, 2160P, 1080P, 720P, 576P, 480P; unknown quality allowed |
| SD | 576P, 480P |
| HD-720p | 720P |
| HD-1080p | 1080P |
| Ultra-HD | 2160P |
| HD - 720p/1080p | 1080P, 720P |

The first tier is archival/cutoff. Upgrades are **off by default**, including
unrelated and built-in profiles. Their other criteria and selections remain stored.
`--upgrades match-source` maps each matching source profile's `upgradeAllowed` to
Scryer's profile-scoped `criteria.allowUpgrades` and verifies it by reading it back.
Unmatched Scryer profiles remain off. There is no independent library upgrade flag:
its effective profile controls this policy.
With the recycle bin off, an approved upgrade permanently deletes the replaced
file after verification, exactly as Sonarr does today. It does not preserve the
old file for rollback. Source: `crates/scryer-application/src/import/upgrade.rs:1668–1671`. These tier mappings cannot reproduce ARR's separate
DVD, WEB, Blu-ray, remux and custom-format ordering. Matching a profile name is a
parity gate, not proof that future release selection is identical.

## Archived, not migrated

Sonarr and Radarr history and blocklists (all pages), their qualityprofiles, and Radarr exclusions, are
archived as GET-only exports. Their history/blocklist records are not inserted
into Scryer. The importer adds TMDb 863 (*Toy Story 2*) and 502356
(*The Super Mario Bros. Movie*) as ALL_LISTS exclusions.
ARR download-client/indexer settings, schedules, users and authentication,
processing receipts, original database state and saved tsnet identities stay
with ARR. Scryer's list exclusions are not an ARR blocklist migration.

## Rollback

Set **only** `library = "arr"` and use the approved normal rebuild procedure.
Sonarr/Radarr and their saved proxies return with their existing gates and receipts.
Scryer stops; its state and API identity remain saved. No mode deletes application
state, gate markers, processing receipts, library media or identity state.
Rollback does not undo any library writes made after an accepted Scryer cutover.
Take another snapshot and check files before admitting restored ARR processing.

The rollback contract compares ARR units, ARR proxy units and the leak-audit JSON
byte-for-byte with Cairn. These NixOS mounts are generated at boot from fstab, not
present as static `systemd.units` at evaluation. The contract compares the exact
fstab bytes and the bindfs/mergerfs filesystem definitions used by that generator.
`scripts/test-media-scryer-generated-mounts` also runs the real fstab generator and
compares all four generated mount units byte-for-byte.
The baseline is Cairn `32f1b351a3ef644628fa13d45a1903f5acafc637`.
The original ARR validator now lives in `media-arr-state-ready.py`; Nix keeps its
original `media-state-ready.py` store basename and exact contents for unchanged units.
The new `media-state-ready.py` dispatches Scryer admission and delegates the ARR API.

## Verified GraphQL source contract

All citations below refer to tag **scryer-v0.21.15** (commit `bb56c3f7`).
The generated `api/graphql/schema.graphql` also confirms field spellings.
Arguments use GraphQL variables; no secret is embedded in operation text.
`POST /graphql` uses `Authorization: Bearer <token>` after login.

| Operation(s) used | Rust source citation |
|---|---|
| `login(input:LoginInput){token passwordChangeRequired}` | `crates/scryer-interface-settings/src/mutation.rs:2430`; `crates/scryer-interface-media-types/src/types/identity.rs:7` |
| `completeRequiredPasswordChange(input:CompleteRequiredPasswordChangeInput){token passwordChangeRequired}` | `crates/scryer-interface-settings/src/mutation.rs:2533`; `crates/scryer-interface-media-types/src/types/identity.rs:270` |
| `createMyApiKey(input:CreateMyApiKeyInput){apiKey}` (label mountainous, expiry NEVER) | `crates/scryer-interface-settings/src/mutation.rs:2379` |
| `completeSetup{completed}` | `crates/scryer-interface-settings/src/mutation.rs:2566` |
| `updateMediaSettings(input:UpdateMediaSettingsInput)`; `mediaSettings(scope)` | `crates/scryer-interface-settings/src/mutation.rs:1573`; `src/lib.rs:1116`; `crates/scryer-interface-media-types/src/types/settings.rs:1137` |
| `updateRecycleBinSettings(input:UpdateRecycleBinSettingsInput)`; `recycleBinSettings` | settings `mutation.rs:951`, `lib.rs:805`; types `settings.rs:1343` |
| `updateAcquisitionSettings(input:UpdateAcquisitionSettingsInput)`; `acquisitionSettings` | settings `mutation.rs:856`, `lib.rs:780`; types `settings.rs:1371` |
| `updateSubtitleSettings(input:UpdateSubtitleSettingsInput)`; `subtitleSettings` | settings `mutation.rs:808`, `lib.rs:769`; types `settings.rs:1314` |
| `updatePluginAutoUpdateSettings(input:UpdatePluginAutoUpdateSettingsInput)`; `pluginAutoUpdateSettings` | settings `mutation.rs:1005`, `lib.rs:833`; types `settings.rs:1364` |
| `saveQualityProfileSettings(input:SaveQualityProfileSettingsInput)`; `qualityProfileSettings` | settings `mutation.rs:1692`, `lib.rs:1169`; types `settings.rs:1423–1517`; `crates/scryer-application/src/quality/profile.rs:383–551` |
| `plugins{id isInstalled installedVersion}` (VM verification) | `crates/scryer-interface-query/src/lib.rs:4199` |
| `installUploadedPlugin(input:ManualPluginUploadInput){id name version}` | `crates/scryer-interface-system/src/plugins.rs:146`; types `plugins.rs:ManualPluginUploadInput` |
| `validateExternalImportConnection(input:ValidateExternalImportConnectionInput){connected}` | `crates/scryer-interface-import/src/lib.rs:1947`; types `external_import.rs:37` |
| `startExternalImportArrSourceWarmup(input:StartExternalImportArrSourceWarmupInput){sessionId status}` | import `lib.rs:1805`; types `external_import.rs:142` |
| `externalImportWarmupStatus(sessionId){status}` | `crates/scryer-interface-query/src/lib.rs:2391` (the researched `externalImportMonitorWarmupStatus` name does not exist) |
| `previewExternalImport(input:PreviewExternalImportInput){arrSources rootFolders}` | import `lib.rs:2014`; types `external_import.rs:167` |
| `finalizeExternalImport(input:FinalizeExternalImportInput){finalizeSessionId monitorWarmupSessionId}` | import `lib.rs:2215`, `3381–3647`; types `external_import.rs:246` (mapping includes required libraryId) |
| `scanLibrary(input:ScanLibraryInput){sessionId status}`; `libraryScanSession(sessionId){status}` | `crates/scryer-interface/src/mutation/library.rs:196`; types `library.rs:458`; query `lib.rs:2356`; upstream wizard `apps/scryer-web/lib/hooks/use-external-import-setup.ts:1424–1460` |
| `addListExclusion(input:AddListExclusionInput){id}` | `crates/scryer-interface/src/mutation/lists.rs:308`; types `lists.rs:1044` |
| `updateTitle(input:UpdateTitleInput{titleId,options:{qualityProfileId}}){id}` | `crates/scryer-interface/src/mutation/titles.rs:464`; types `library.rs:936,1202` |
| `titles(limit,offset){hasMore items{...}}`; `libraries{id facet roots}` | query `lib.rs:1206,1350`; title media/collection/episode fields in `crates/scryer-interface-media/src/types.rs`, `complex.rs:781,835,1162` |
| `qualityTier` (effective profile **name**, not file resolution) | media `complex.rs:137`; `crates/scryer-application/src/settings/runtime/quality_profiles.rs:256` |
| `indexers{id baseUrl}` | `crates/scryer-interface-settings/src/lib.rs:1222`; types `acquisition.rs:IndexerConfigPayload` |

Setting keys were checked in `crates/scryer-application/src/settings/keys.rs`:
`rename.enabled`, `import.mode`, `recycle_bin.enabled`, `plugins.auto_update.enabled`,
and the movie/series/anime path keys. `ImportModeValue::HardlinkOrCopy` is encoded
`HARDLINK_OR_COPY` (`types/schema_values.rs:1384`). The commands use typed settings
mutations instead of writing setting keys or editing Scryer's database.


### Review fixes: source contract and verification

- `allowUpgrades` is on `QualityProfileCriteriaInput/Payload`, not a media or
  library flag: `crates/scryer-interface-media-types/src/types/settings.rs:706–748,1423–1462`.
  `saveQualityProfileSettings` persists it (`settings/mutation.rs:1692`).
- Library overrides are exposed as `libraries.settings` and `librarySettings`:
  `crates/scryer-interface-media/src/complex.rs:101`;
  `crates/scryer-interface-query/src/lib.rs:1446`;
  `crates/scryer-interface-media-types/src/types/library.rs:34–125`.
  Rename/recycle/acquisition/subtitle/plugin enablement have no library override
  in that model. Import mode, NFO/Plex writes, permission settings and profile
  references do. The guard checks both effective values and those overrides.
- Metadata-only `addTitle(input:AddTitleInput)` returns `title`, `downloadJobId`
  and `reusedQueuedDownload`: `crates/scryer-interface/src/mutation/titles.rs:321–378`.
  It sets no download job; `new_title_for_library` sets `folder_path: None`, and
  creation writes only catalog/options/events: `crates/scryer-application/src/catalog/workflow/hydration.rs:428–561`.
  `finish_add_title_with_outcome` wakes metadata hydration, not a search
  (`catalog/workflow/titles.rs:954–986`). Background acquisition checks its
  enablement (`acquisition/workflow/task_runner.rs:5517`). Source series/episode
  coverage is awaited because monitoring only updates existing rows
  (`catalog/workflow/monitoring.rs:498–615`).
- The VM review fixture has 25 movies and 18 series. It starts with 34 records,
  adds the missing six movies/three series, verifies parity for all 43, repeats
  idempotently and compares filesystem snapshots. This is a fixture, not a live
  Unzen parity result. The VM also tests three password-interruption windows,
  explicit upgrade matching, late writable mounts and library-mount restart.
