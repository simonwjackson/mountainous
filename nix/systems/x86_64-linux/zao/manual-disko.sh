#!/usr/bin/env nix-shell
#! nix-shell -i bash -p parted util-linux mdadm dosfstools f2fs-tools xfsprogs
# Manual disko setup for zao system
# Based on nix/systems/x86_64-linux/zao/disko.nix
# nix run github:nix-community/nixos-anywhere -- --flake .#zao --phases install,reboot --build-on-remote nixos@<target-ip>

set -euo pipefail

# Disk device IDs
USB1="/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374119080022027-0:0"
USB2="/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0330119070016269-0:0"
NVME1="/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890"
NVME2="/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725"

echo "=== Stopping any existing RAID arrays ==="
# Stop arrays if they exist (ignore errors if they don't)
mdadm --stop /dev/md/backup 2>/dev/null || true
mdadm --stop /dev/md/boot 2>/dev/null || true
mdadm --stop /dev/md/blizzard 2>/dev/null || true
mdadm --stop /dev/md/blizzard0 2>/dev/null || true

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
mdadm --zero-superblock "${NVME1}-part1" 2>/dev/null || true
mdadm --zero-superblock "${NVME1}-part2" 2>/dev/null || true
mdadm --zero-superblock "${NVME2}-part1" 2>/dev/null || true
mdadm --zero-superblock "${NVME2}-part2" 2>/dev/null || true

echo ""
echo "=== Wiping existing partition tables ==="
wipefs -af "$USB1" "$USB2" "$NVME1" "$NVME2" || true

# Force kernel to re-read partition tables
partprobe "$USB1" "$USB2" "$NVME1" "$NVME2" || true
sleep 2

echo ""
echo "=== Partitioning USB Drive 1 (sleet.0.00) ==="
parted -s "$USB1" -- mklabel gpt
parted -s "$USB1" -- mkpart BOOT 1MiB 2MiB
parted -s "$USB1" -- set 1 bios_grub on
parted -s "$USB1" -- mkpart ESP 2MiB 2050MiB
parted -s "$USB1" -- set 2 esp on
parted -s "$USB1" -- mkpart BACKUP 2050MiB 29050MiB

echo ""
echo "=== Partitioning USB Drive 2 (sleet.0.01) ==="
parted -s "$USB2" -- mklabel gpt
parted -s "$USB2" -- mkpart BOOT 1MiB 2MiB
parted -s "$USB2" -- set 1 bios_grub on
parted -s "$USB2" -- mkpart ESP 2MiB 2050MiB
parted -s "$USB2" -- set 2 esp on
parted -s "$USB2" -- mkpart BACKUP 2050MiB 29050MiB

echo ""
echo "=== Partitioning NVMe Drive 1 (blizzard.0.00) ==="
parted -s "$NVME1" -- mklabel gpt || true
parted -s "$NVME1" -- mkpart mdadm 1MiB 1894402MiB || true # 1850GiB

echo ""
echo "=== Partitioning NVMe Drive 2 (blizzard.0.01) ==="
parted -s "$NVME2" -- mklabel gpt || true
parted -s "$NVME2" -- mkpart mdadm 1MiB 1894402MiB || true # 1850GiB

# Wait for kernel to recognize partitions
sleep 2
partprobe "$USB1" "$USB2" "$NVME1" "$NVME2"

echo ""
echo "=== Wiping partition signatures ==="
wipefs -af "${USB1}-part2" "${USB1}-part3" "${USB2}-part2" "${USB2}-part3" "${NVME1}-part1" "${NVME2}-part1"

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
mdadm --remove /dev/md/blizzard0 2>/dev/null || true

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

echo ""
echo "=== Creating RAID0 system array (md/blizzard0) ==="
mdadm --create /dev/md/blizzard0 \
  --homehost=any \
  --force \
  --run \
  --level=0 \
  --raid-devices=2 \
  --metadata=1.2 \
  "${NVME1}-part1" \
  "${NVME2}-part1"

# Wait for arrays to initialize
sleep 2

echo ""
echo "=== Formatting boot partition (vfat) ==="
mkfs.vfat -F 32 -n BOOT /dev/md/boot

echo ""
echo "=== Formatting backup partition (f2fs) ==="
mkfs.f2fs -f -l BACKUP /dev/md/backup

echo ""
echo "=== Creating GPT on blizzard0 array ==="
parted -s /dev/md/blizzard0 -- mklabel gpt
parted -s /dev/md/blizzard0 -- mkpart primary 0% 100%

sleep 3
partprobe /dev/md/blizzard0
sleep 2

# Wait for partition to appear
echo "Waiting for /dev/md/blizzard0p1 to appear..."
for i in {1..10}; do
  [ -e /dev/md/blizzard0p1 ] && break
  sleep 1
done

echo ""
echo "=== Formatting blizzard partition (xfs) ==="
mkfs.xfs -f -L nixos /dev/md/blizzard0p1

echo ""
echo "=== Mounting filesystems ==="
mount /dev/md/blizzard0p1 /mnt

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
