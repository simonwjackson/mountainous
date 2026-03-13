# Fuji boot-volume resize plan (do not run yet)

Date: 2026-03-13
Host: `fuji`
Status: **planning only**

## Important

**Do not make OCI changes to `fuji` yet.**
This file is only a handoff/runbook for later execution from `yari`.

## Current observed state

Checked live on `fuji`:

- `/` on `/dev/sda2` = `47G` total, `41G` used, `5.2G` free (`89%` used)
- `/boot` on `/dev/sda1`
- `/data` on `/dev/sdb1` = `153G` total, `3.0G` used, `150G` free (`2%` used)

Block devices:

- `/dev/sda` = `46.6G`
  - `/dev/sda1` = `512M` vfat mounted at `/boot`
  - `/dev/sda2` = `46.1G` xfs mounted at `/`
- `/dev/sdb` = `153G`
  - `/dev/sdb1` = `153G` xfs mounted at `/data`

Repo config also matches a two-disk layout:

- `hosts/fuji/disko.nix`
  - boot disk by-id: `scsi-360dcd7caf93c46798175207d39b51cf7`
  - data disk by-id: `scsi-36076c8dfc27a4c699aedd8d3b6965dec`

## Goal

Make `fuji` like `yari` now is:

- one larger OCI boot volume
- one root filesystem on XFS
- no separate `/data` block volume
- remain within OCI Always Free storage budget

## Critical difference from `yari`

Unlike `yari`, `fuji` currently **does have a mounted data disk** at `/data`.
That means before deleting the data volume later, decide one of these:

1. the contents of `/data` are disposable, or
2. copy anything needed from `/data` onto `/` or elsewhere first, or
3. take a backup elsewhere before OCI-side changes

As of the check above, `/data` only had about `3G` used, so migration should be manageable.

## Later execution plan

### Phase 1: verify OCI profile and object IDs from `yari`

From `yari`, first determine whether OCI credentials are present locally or reachable another way.
If needed, use `nix shell nixpkgs#oci-cli -c oci ...`.

Verify all of the following before any destructive action:

- OCI profile for `fuji`
- instance OCID for `fuji`
- boot volume OCID for `fuji`
- block volume OCID for the `/data` disk
- volume attachment OCID for the `/data` disk

### Phase 2: OCI-side operations

Do these only when ready:

1. stop `fuji`
2. detach the `/data` block volume
3. delete the `/data` block volume
4. resize the boot volume upward to consume the freed Always Free storage budget
5. start `fuji`

### Phase 3: guest-side resize on `fuji`

After OCI reports the boot volume is larger and `fuji` is back up, run:

```sh
sudo nix shell nixpkgs#cloud-utils -c /nix/store/*cloud-utils*/bin/growpart /dev/sda 2
sudo xfs_growfs /
df -hT /
lsblk -e7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT /dev/sda
```

If the wildcard path is annoying, first resolve it explicitly:

```sh
ls /nix/store/*cloud-utils*/bin/growpart
```

Then run the exact path, for example:

```sh
sudo /nix/store/<cloud-utils-store-path>/bin/growpart /dev/sda 2
sudo xfs_growfs /
```

## Expected end state

- `/dev/sda` expanded to the new OCI boot volume size
- `/dev/sda2` expanded to fill the disk
- `/` grows substantially
- `/data` no longer exists as a separate block volume/mount

## Suggested preflight checks for later

Before touching OCI later, re-run:

```sh
df -hT / /data /boot
lsblk -e7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,PATH
```

Also check whether anything important is still under `/data`:

```sh
sudo du -sh /data/* 2>/dev/null | sort -h
```

## Reminder

This file is intentionally just a later runbook.
**No changes to `fuji` have been made yet.**
