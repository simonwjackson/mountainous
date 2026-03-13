---
date: 2026-03-13
topic: yari-btrfs-oci-reinstall
---

# Yari Btrfs OCI Reinstall

## What We're Building
Evaluate whether `yari` can be reinstalled with `nixos-anywhere` and a Btrfs layout that uses both the existing 50 GiB boot volume and the attached 150 GiB OCI block volume.

The key question is not whether Btrfs can span two devices in general — it can — but whether this is a good fit when one of the devices is an OCI iSCSI-attached volume that is not automatically present as a local block device during early boot.

## Why This Approach
We considered four approaches:

1. Single larger boot volume, then reinstall onto that one disk.
2. Single multi-device Btrfs filesystem spanning both disks for `/`.
3. Keep `/` on the boot volume and use the 150 GiB volume separately for data or `/nix`.
4. Rework OCI attachment mode first (for example, only proceed if the second volume can appear early and reliably enough at boot).

Recommendation: the cleanest outcome is a genuinely larger single boot volume if OCI resizing or rebuild flow allows it. Failing that, avoid a multi-device Btrfs root across the current OCI boot disk + iSCSI data volume. Prefer keeping `/` on the boot volume and using the 150 GiB volume for `/nix` or other high-growth paths, unless OCI attachment behavior is changed to something that is available before the root filesystem must mount.

## Key Decisions
- Btrfs multi-device is technically possible: Disko examples and Btrfs documentation support multi-device filesystems.
- Current OCI attachment type matters more than Btrfs capability: the extra `yari-data` volume is attached as `iSCSI`, not paravirtualized.
- Current OCI behavior is a boot risk: OCI docs state paravirtualized volumes connect automatically, while iSCSI-attached volumes must be connected and mounted from inside the instance.
- Therefore, a root filesystem spanning `/dev/sda` plus the iSCSI volume would be fragile during boot and reinstall.
- If the goal is a true "single virtual disk" experience, resizing/replacing the OCI boot volume is cleaner than spanning the boot disk with an iSCSI data volume.
- Best practical fallback: keep ESP + root on the boot disk, and put `/nix` (the main growth path) on the 150 GiB volume so the operational problem goes away even without a single combined root filesystem.

## Resolved Questions
- Can Btrfs combine the capacities? Yes, with an appropriate multi-device profile such as `-d single -m raid1` for uneven disks.
- Should that be used for the root filesystem on `yari` as currently attached? Probably not, because the second device is iSCSI and is not present automatically at early boot.
- What is the closest safe approximation to a single larger system disk without changing OCI boot storage? Put `/nix` on the 150 GiB volume, because that is the dominant space consumer.

## Open Questions
- Can OCI expose the extra volume to this instance in a way that is reliably present in initrd/early boot, rather than requiring post-boot iSCSI login?
- If not, should the 150 GiB volume be dedicated to `/nix`, or split between `/nix` and another growth path such as `/var/lib` or `/srv`?
- Is resizing the OCI boot volume acceptable as the preferred route to a true single-disk system?

## Next Steps
→ If proceeding, plan a reinstall that keeps `/boot` + `/` on the 50 GiB boot volume and uses the 150 GiB volume as a separate filesystem managed by Disko and `nixos-anywhere`.
