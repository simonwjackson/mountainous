#!/usr/bin/env nix-shell
#! nix-shell -i bash -p parted util-linux mdadm dosfstools f2fs-tools xfsprogs
# Manual disko setup for kita system (Intel NUC8i3BEK)
# Based on nix/systems/x86_64-linux/kita/disko.nix
# Cloned from zao with single SSD instead of RAID0 NVMe
# nix run github:nix-community/nixos-anywhere -- --flake .#kita --phases install,reboot --build-on-remote nixos@<target-ip>

set -euo pipefail

# Disk device IDs
USB1="/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C530000230426119230-0:0"
USB2="/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0"
SSD="/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D"

echo "=== Stopping any existing RAID arrays ==="
# Stop arrays if they exist (ignore errors if they don't)
mdadm --stop /dev/md/backup 2>/dev/null || true
mdadm --stop /dev/md/boot 2>/dev/null || true

# Stop any auto-assembled arrays (md127, md126, md125, etc.)
for md in /dev/md/md* /dev/md[0-9]* /dev/md1[0-9]*; do
  [ -e "$md" ] && mdadm --stop "$md" 2>/dev/null || true
done

echo ""
echo "=== Wiping RAID metadata from partitions ==="
# Zero out RAID superblocks from any existing partitions
mdadm --zero-superblock "${USB1}-part2" 2>/dev/null || true
mdadm --zero-superblock "${USB1}-part3" 2>/dev/null || true
mdadm --zero-superblock "${USB2}-part2" 2>/dev/null || true
mdadm --zero-superblock "${USB2}-part3" 2>/dev/null || true
mdadm --zero-superblock "${SSD}-part1" 2>/dev/null || true

echo ""
echo "=== Wiping existing partition tables ==="
wipefs -af "$USB1" "$USB2" "$SSD" || true

# Force kernel to re-read partition tables
partprobe "$USB1" "$USB2" "$SSD" || true
sleep 2

echo ""
echo "=== Partitioning USB Drive 1 (sleet.0.00) ==="
parted -s "$USB1" -- mklabel gpt
parted -s "$USB1" -- mkpart BOOT 1MiB 2MiB
parted -s "$USB1" -- set 1 bios_grub on
parted -s "$USB1" -- mkpart ESP 2MiB 2050MiB
parted -s "$USB1" -- set 2 esp on
parted -s "$USB1" -- mkpart BACKUP 2050MiB 28050MiB

echo ""
echo "=== Partitioning USB Drive 2 (sleet.0.01) ==="
parted -s "$USB2" -- mklabel gpt
parted -s "$USB2" -- mkpart BOOT 1MiB 2MiB
parted -s "$USB2" -- set 1 bios_grub on
parted -s "$USB2" -- mkpart ESP 2MiB 2050MiB
parted -s "$USB2" -- set 2 esp on
parted -s "$USB2" -- mkpart BACKUP 2050MiB 28050MiB

echo ""
echo "=== Partitioning Main SSD (blizzard.0.00) ==="
parted -s "$SSD" -- mklabel gpt
parted -s "$SSD" -- mkpart disk-blizzard.0.00-primary 1MiB 100%

# Wait for kernel to recognize partitions
sleep 2
partprobe "$USB1" "$USB2" "$SSD"

echo ""
echo "=== Wiping partition signatures ==="
# Wipe each partition individually, ignoring errors for non-existent partitions
wipefs -af "${USB1}-part2" 2>/dev/null || true
wipefs -af "${USB1}-part3" 2>/dev/null || true
wipefs -af "${USB2}-part2" 2>/dev/null || true
wipefs -af "${USB2}-part3" 2>/dev/null || true
wipefs -af "${SSD}-part1" 2>/dev/null || true

# Stop any auto-assembled arrays again after wipefs
echo ""
echo "=== Stopping any auto-assembled arrays ==="
sleep 2
for md in /dev/md/md* /dev/md[0-9]* /dev/md1[0-9]*; do
  [ -e "$md" ] && mdadm --stop "$md" 2>/dev/null || true
done

# Remove any lingering device nodes
mdadm --remove /dev/md/boot 2>/dev/null || true
mdadm --remove /dev/md/backup 2>/dev/null || true

# Wait for devices to be fully released
sleep 3

echo ""
echo "=== Creating RAID1 boot array (md/boot) ==="
mdadm --create /dev/md/boot \
  --homehost=any \
  --force \
  --run \
  --level=1 \
  --raid-devices=2 \
  --metadata=1.0 \
  "${USB1}-part2" \
  "${USB2}-part2"

echo ""
echo "=== Creating RAID1 backup array (md/backup) ==="
mdadm --create /dev/md/backup \
  --homehost=any \
  --force \
  --run \
  --level=1 \
  --raid-devices=2 \
  --metadata=1.2 \
  "${USB1}-part3" \
  "${USB2}-part3"

# Wait for arrays to initialize
sleep 2

echo ""
echo "=== Formatting boot partition (vfat) ==="
mkfs.vfat -F 32 -n BOOT /dev/md/boot

echo ""
echo "=== Formatting backup partition (f2fs) ==="
mkfs.f2fs -f -l BACKUP /dev/md/backup

echo ""
echo "=== Formatting system partition (xfs) ==="
mkfs.xfs -f -L nixos "${SSD}-part1"

echo ""
echo "=== Mounting filesystems ==="
mount "${SSD}-part1" /mnt

mkdir -p /mnt/boot
mount /dev/md/boot /mnt/boot

mkdir -p /mnt/tundra/usb-backup
mount -o noatime,nodiratime,background_gc=on,gc_merge,lazytime /dev/md/backup /mnt/tundra/usb-backup

echo ""
echo "=== Disk setup complete! ==="
echo ""
echo "Array status:"
cat /proc/mdstat
echo ""
echo "Mounted filesystems:"
df -h | grep -E '(Filesystem|/mnt)'
