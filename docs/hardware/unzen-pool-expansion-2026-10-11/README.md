# Unzen online pool expansion

Samsung and Sabrent are now members of filesystem `e5f61013-d6f5-260d-9883-4dda26b2c293`. Live admission passed on 2026-10-11 at 14:12:54 UTC. The filesystem has three online members and one offline member. The Kioxia controller fault remains unresolved.

## Approved scope and backup

The operator selected `erase_and_add` for Samsung serial `S4P4NF0M317686M` and Sabrent serial `470207171EA300001068`. The approval allowed erasing those two drives and adding them online. It did not allow reformatting an existing member, rebooting, or changing bootloaders. None of those excluded actions occurred.

The independent backup is `zao:/srv/lakes/towada/backups/unzen-camera-20261011T053958Z`, on `/srv/shores/towada/00`. It contains 10,700 files and 80,184,170,900 bytes. Every copied file passed SHA-256 verification against the original-source manifests. The backup preserves all 7,692 Sabrent files and 3,008 Samsung image files. It does not preserve Samsung non-image data, including the nine previously identified TV downloads. The operator received this exclusion before approval.

## Actual membership

| Member | Serial | State | Failure domain |
|---|---|---|---|
| `onboard.kioxia` | `81UFC0UWF8T3` | Offline, unchanged. | `onboard.kioxia` |
| `onboard.sn770` | `22135C800678` | Online read-write, unchanged. | `onboard.sn770` |
| `card.samsung` | `S4P4NF0M317686M` | Online read-write, whole-disk member. | `pcie-card` |
| `card.sabrent` | `470207171EA300001068` | Online read-write, whole-disk member. | `pcie-card` |

The new members use their serial-bearing `/dev/disk/by-id/nvme-*` paths. They have no EFI partitions. Both `data_replicas` and `metadata_replicas` remain `2`. Each member has durability `1`. Both new superblocks retain the original filesystem UUID, all four member records, both replica settings, and the shared card failure domain.

## Native add and failure-domain correction

The native `bcachefs device add` operation succeeded for Samsung. The first application script then stopped because its live member admission found an empty failure domain. On the installed `bcachefs-tools` 1.39.6, the add command accepts `--failure_domain=pcie-card` but did not apply it to this live member. The command's success did not prove the option took effect.

The inspected partial receipt is `/var/lib/storage-expansion/unzen-20261011T140051Z/receipt.json`. The resume path admitted Samsung by serial, filesystem UUID, online member identity, policy, and SMART health. It did not erase or add Samsung again. It assigned `pcie-card` through the member's writable sysfs `failure_domain` option and verified the result. Sabrent was then erased and added, with the same live-option verification. A brief 524,288-byte card-domain exposure cleared before final admission.

One resume preflight also stopped at the NVMe temperature/spare guard. Later SMART checks passed. The final composite temperatures were 35 degrees Celsius for Sabrent, 54 for Samsung, and 52 for SN770. All three online drives reported zero critical warnings and zero media errors. This is a current observation, not a guarantee of cooling under sustained load.

## Verification

The updated `tests/unzen-storage.nix` passed the real NixOS VM check at `/nix/store/kw2vwb508nxyzjiz2lcmcagykdjy0ry8-vm-test-run-disko-unzen-storage`. Each original member was independently omitted in a separate fixture. The test booted the survivor, preserved existing and degraded-write markers, added a replacement online, verified live failure-domain assignment and the two-copy policy, and waited for zero reported single-domain loss. It also retained the original healthy-pool expansion test. Ruff checks, Ruff formatting, Nix formatting, and `git diff --check` passed.

Physical checks passed:

- Both new member identities, labels, failure domains, durability values, and filesystem UUID matched the approved plan.
- A new 1 MiB marker passed a synchronized write/read comparison.
- `bcachefs reconcile status /srv` reported scan pending `0` and zero pending data and metadata work in every reported category.
- `bcachefs fs failure-domains --json /srv` reported four registered devices, one offline device, `separation_violated=false`, and `lost_bytes=0` for every domain.
- Both new on-disk superblocks confirmed the persisted card domain and unchanged replica settings.
- The boot ID remained `f2acd2c8-fbbb-4287-9419-1a4d37ef94f9`.

See [expansion.json](./expansion.json) for the durable operation receipt and [postflight.json](./postflight.json) for the later direct checks. The live receipt is `/var/lib/storage-expansion/unzen-20261011T140928Z/receipt.json`.

## Remaining limits

This operation does not repair or replace Kioxia. Do not rebuild bootloaders against its unavailable `/boot` filesystem. Unattended firmware fallback and boot with this expanded membership were not tested because no reboot was authorized.

The shared card domain records a common failure point. Bcachefs failure-domain placement is a preference, not a hard guarantee when independent domains run out of space. Keep headroom on SN770 and retain the independent Towada backup. Raw capacity and `df` output do not establish protected usable capacity. The offline Kioxia also remains registered in filesystem accounting.

Disko remains the initial two-drive installation plan. Do not rerun Disko against the expanded filesystem. Existing mounts still use the unchanged filesystem UUID. This online expansion needed no NixOS activation or deployment.
