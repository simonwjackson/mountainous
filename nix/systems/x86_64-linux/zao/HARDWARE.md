# Hardware Documentation: zao

## Overview

**zao** is a high-performance gaming laptop repurposed as an always-on server/gaming streaming system. It features hybrid Intel/NVIDIA graphics, dual NVMe storage in RAID0, and SD card boot for system redundancy.

**Form Factor**: Gaming Laptop (configured as 24/7 server)
**Primary Use**: Game streaming server with Sunshine
**Boot Method**: SD Card (EFI) + Dual NVMe (storage)
**Architecture**: x86_64 (Intel 11th Gen)

---

## Processor

### CPU Specifications
- **Model**: Intel Core i9-11900H (Tiger Lake, 11th Gen)
- **Architecture**: x86_64
- **Base Clock**: 2.5 GHz
- **Boost Clock**: Up to 4.9 GHz
- **Cores/Threads**: 8 cores / 16 threads
- **TDP**: 35W (configurable 35-65W)
- **Cache**: 24MB Intel Smart Cache
- **Process Node**: 10nm SuperFin
- **Instruction Sets**: SSE4.2, AVX2, AVX-512

### NixOS Configuration
```nix
boot.kernelModules = ["kvm-intel"];
hardware.cpu.intel.updateMicrocode = true;
powerManagement.cpuFreqGovernor = "performance";
```

**Notes**:
- KVM virtualization enabled for potential VM workloads
- Performance governor ensures consistent high performance (no battery optimization)
- Intel microcode updates enabled for security patches

---

## Graphics

### Hybrid Graphics Setup

#### Integrated GPU (Primary)
- **Model**: Intel UHD Graphics (Tiger Lake GT1)
- **Driver**: i915 (kernel module)
- **PCI Bus ID**: 0:2:0
- **Execution Units**: 32 EUs
- **Max Frequency**: 1.45 GHz
- **Video Memory**: Shared system RAM
- **Display Outputs**: Drives internal display by default

**Video Acceleration**:
- `intel-media-driver` (iHD) - Modern VAAPI driver
- `intel-vaapi-driver` (i965) - Legacy VAAPI driver (better compatibility)
- Both 32-bit and 64-bit libraries installed

#### Discrete GPU (NVIDIA Prime Offload)
- **Model**: NVIDIA GeForce RTX 3060 Mobile (GA106M)
- **PCI Bus ID**: 1:0:0
- **CUDA Cores**: 3840
- **Memory**: 6GB GDDR6
- **Memory Bus**: 192-bit
- **TGP**: 60-115W (laptop variant)
- **Architecture**: Ampere (GA106)

**Driver Configuration**:
```nix
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
};
```

**Usage**:
- Intel GPU: Default for desktop/2D workloads (power efficiency)
- NVIDIA GPU: On-demand via `nvidia-offload` command or PRIME offload
- Gaming/streaming: Sunshine uses NVIDIA for encoding

**Known Limitations**:
- Fine-grained power management disabled (may impact idle power)
- Open-source NVIDIA kernel modules NOT used (proprietary driver required)

---

## Storage Architecture

### Boot Device: SD Card
- **Capacity**: 32GB
- **Device ID**: `mmc-SD32G_0xfcf357fa`
- **Partition**: 2GB EFI System Partition (FAT32)
- **Mount Point**: `/boot`
- **Bootloader**: GRUB (EFI, installed as removable)

**Rationale**:
- Simple, reliable boot isolation
- Easy recovery/reinstallation
- Protects boot partition from NVMe failures
- GRUB installed to `/EFI/BOOT/BOOTX64.EFI` for maximum compatibility

**Considerations**:
- SD cards have limited write endurance (GRUB updates should be infrequent)
- FAT32 filesystem (no journaling, but suitable for read-mostly boot partition)
- `efi.canTouchEfiVariables = false` (safe for removable media)

### Primary Storage: Dual NVMe Btrfs RAID0
- **Drive 1**: WD Blue SN570 2TB (`nvme-WD_Blue_SN570_2TB_22343V800890`)
- **Drive 2**: WD Blue SN570 2TB (`nvme-WD_Blue_SN570_2TB_22343V800725`)

**Specifications (per drive)**:
- **Capacity**: 2TB
- **Interface**: NVMe 1.4 (PCIe Gen3 x4)
- **Form Factor**: M.2 2280
- **Sequential Read**: Up to 3,500 MB/s
- **Sequential Write**: Up to 3,000 MB/s
- **Controller**: SanDisk 20-82-10081-A1
- **NAND**: TLC (Triple-Level Cell)
- **DRAM Cache**: No (HMB - Host Memory Buffer)
- **Endurance**: 600 TBW (Terabytes Written)

**RAID Configuration**:
```
Data:     RAID0 (striped across both drives)
Metadata: RAID1 (mirrored on both drives)
```

**Benefits**:
- **Performance**: ~2x read/write throughput from striping
- **Capacity**: Full 4TB usable
- **Safety**: Metadata mirrored prevents corruption from single drive failure

**Risks**:
- **Data RAID0**: Loss of either drive = total data loss
- **Backup**: Critical for this configuration (no redundancy for data)

### Btrfs Subvolumes
| Subvolume | Mount Point | Purpose |
|-----------|-------------|---------|
| `@nix` | `/nix` | Nix store (immutable packages) |
| `@log` | `/var/log` | System logs (persistent across reboots) |
| `@permafrost` | `/tundra/permafrost` | Persistent user/system data |

**Mount Options**:
```
compress=zstd       # Transparent compression (saves space, slight CPU cost)
noatime             # Don't update access times (performance)
nodiratime          # Don't update directory access times
discard=async       # Async TRIM for SSD health
space_cache=v2      # Improved free space tracking
```

### Ephemeral Root (tmpfs)
```nix
fileSystems."/" = {
  device = "none";
  fsType = "tmpfs";
  options = ["defaults" "size=2G" "mode=755"];
};
```

**Characteristics**:
- Root filesystem is 2GB RAM-backed tmpfs
- Cleared on every reboot (stateless system)
- Persistent data managed via impermanence to `/tundra/permafrost`

**Benefits**:
- Clean state on every boot
- No root filesystem wear on SSDs
- Enforces declarative configuration

---

## Connectivity

### Thunderbolt
- **Support**: Yes (Tiger Lake integrated)
- **Kernel Module**: `thunderbolt`, `xhci_pci`
- **Version**: Thunderbolt 4 (USB4 compatible)

**Capabilities**:
- 40 Gbps bandwidth
- PCIe tunneling
- DisplayPort 1.4a
- USB 3.2 Gen 2 (10 Gbps)
- Power Delivery (up to 100W)

### Bluetooth
- **Enabled**: Yes (`hardware.bluetooth.enable = true`)
- **Version**: Likely Bluetooth 5.x (Tiger Lake standard)
- **Use Cases**: Controllers, peripherals

### SD Card Reader
- **Controller**: Realtek (`rtsx_pci_sdmmc` module)
- **Type**: Built-in card reader
- **Current Use**: Hosts 32GB boot SD card

### Unknown/To Be Verified
- **Wi-Fi**: Chipset, driver, 802.11 version (likely Intel AX201/AX211)
- **Ethernet**: Chipset, speed (likely 1GbE or 2.5GbE)
- **USB Ports**: Exact count, USB-C/A breakdown, Thunderbolt ports
- **Display Outputs**: HDMI version, DisplayPort/Thunderbolt displays

---

## Display and Input

### To Be Verified
The following specs are typical for gaming laptops of this class but not confirmed:

**Expected Display**:
- **Size**: 15.6" or 17.3"
- **Resolution**: 1920x1080 (FHD) or 2560x1440 (QHD)
- **Refresh Rate**: 120Hz, 144Hz, or 240Hz (gaming laptop standard)
- **Panel Type**: IPS or fast IPS
- **G-Sync**: Possibly (common with RTX 3060)

**Current Configuration**:
```nix
mountainous.gaming.streaming.monitors.primary = "DP-1";
```
- Primary monitor set to DP-1 (DisplayPort output)
- Suggests external monitor use for game streaming

**Input Devices**:
- Keyboard: Built-in (unknown layout/features)
- Touchpad: Built-in (unknown precision touchpad support)
- Webcam: Unknown (typical for laptops)

---

## Memory (RAM)

### To Be Verified
- **Capacity**: Unknown (likely 16GB or 32GB for RTX 3060 laptop)
- **Type**: DDR4 (standard for 11th Gen Intel)
- **Speed**: Unknown (likely 3200 MHz)
- **Configuration**: Unknown (2x8GB or 2x16GB dual-channel)
- **Expandability**: Unknown (depends on laptop model)

**Expected**:
- Gaming laptops with i9-11900H + RTX 3060 typically ship with 16-32GB
- DDR4-3200 dual-channel is standard for this platform

**How to Check**:
```bash
# On running system:
free -h
lsmem
dmidecode -t memory
```

---

## Power Management

### Server-Optimized Configuration
```nix
services.auto-cpufreq.enable = lib.mkForce false;
powerManagement.cpuFreqGovernor = "performance";

services.logind.settings.Login = {
  HandleLidSwitch = "ignore";
  HandleLidSwitchExternalPower = "ignore";
  HandleLidSwitchDocked = "ignore";
  HandlePowerKey = "ignore";
  IdleAction = "ignore";
};
```

**Behavior**:
- Lid closing: Ignored (system stays on)
- Power button: Ignored
- CPU governor: Performance (no frequency scaling)
- Auto CPU frequency management: Disabled
- Idle actions: Disabled

**Rationale**:
- Configured for 24/7 operation as game streaming server
- Always connected to AC power
- Battery health not prioritized (if battery present)

**Considerations**:
- Higher idle power consumption
- Battery (if present) may degrade faster from constant charging
- No thermal throttling disabled (CPU will still protect itself)

---

## Laptop Model

### Unknown - To Be Identified
The exact laptop model/brand is not specified in the configuration. Based on hardware:

**Candidates**:
- MSI GE/GP series (11th Gen i9 + RTX 3060)
- ASUS ROG Strix/Zephyrus (Tiger Lake H + RTX 3060)
- Alienware m15 R5/R6 (i9-11900H variant)
- Razer Blade 15 (Advanced 2021)
- Gigabyte AORUS/AERO series

**How to Identify**:
```bash
# On running system:
sudo dmidecode -t system
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/sys_vendor
```

**Why It Matters**:
- Vendor-specific quirks/fixes
- Thermal design (cooling capacity)
- Upgrade paths (RAM, storage slots)
- Support/warranty information

---

## NixOS-Specific Configuration

### Kernel Modules (initrd)
```nix
availableKernelModules = [
  "xhci_pci"          # USB 3.x host controller
  "thunderbolt"       # Thunderbolt support
  "nvme"              # NVMe storage
  "uas"               # USB Attached SCSI
  "sd_mod"            # SD card support
  "rtsx_pci_sdmmc"    # Realtek SD card reader
];
```

### Firmware
```nix
hardware.enableRedistributableFirmware = true;
```
- Enables non-free firmware (Wi-Fi, Bluetooth, GPU)
- Required for NVIDIA drivers
- Required for Intel wireless (if present)

### State Version
```nix
system.stateVersion = "25.05";
```
- NixOS 25.05 (development/unstable branch)
- Indicates recent/bleeding-edge configuration

---

## Performance Characteristics

### Expected Performance (Theoretical)

**Storage Throughput** (RAID0 on dual SN570):
- Sequential Read: ~7,000 MB/s (2x 3,500)
- Sequential Write: ~6,000 MB/s (2x 3,000)
- Random Read: ~500k IOPS
- Random Write: ~600k IOPS

**GPU Performance** (RTX 3060 Mobile):
- 1080p gaming: 60-144 FPS (varies by game)
- Ray tracing: 30-60 FPS with DLSS
- Video encoding: NVENC (H.264/HEVC hardware encoding)

**CPU Performance** (i9-11900H):
- Cinebench R23 Multi: ~12,000-13,000
- Single-thread: ~1,500-1,600
- Sustained workloads: May throttle depending on cooling

### Real-World Considerations
- **Thermal**: Laptop cooling may limit sustained performance
- **Power**: Server mode (performance governor) = higher power draw
- **RAID0**: Actual performance depends on workload (not all tasks benefit)
- **Compression**: Zstd compression trades CPU for storage speed/space

---

## Optimization Recommendations

### Critical
1. **Implement Backups**: RAID0 offers zero redundancy
   - Regular backups to external storage or NAS
   - Consider automated Btrfs snapshots to external drive
   - Cloud backup for critical data

2. **Monitor Drive Health**:
   ```bash
   # Check NVMe SMART data
   sudo smartctl -a /dev/nvme0
   sudo smartctl -a /dev/nvme1

   # Btrfs scrub (verify checksums)
   sudo btrfs scrub start /tundra/permafrost
   sudo btrfs scrub status /tundra/permafrost
   ```

### Performance
3. **RAM Tuning**: Verify RAM capacity and consider upgrade
   - 32GB recommended for game streaming + VMs
   - Check if XMP/DOCP profile enabled in BIOS

4. **Thermal Management**:
   - Monitor temperatures under load
   - Consider laptop cooling pad
   - Clean dust from vents periodically
   - Repaste thermal compound if temps high

5. **Storage Optimization**:
   - Enable Btrfs auto-defragmentation for large files:
     ```nix
     services.btrfs.autoScrub.enable = true;
     ```
   - Monitor fragmentation on `/nix` (many small files)

### Power Efficiency (if desired)
6. **Consider Selective Performance**:
   - Use `ondemand` or `schedutil` governor instead of `performance`
   - Re-enable NVIDIA fine-grained power management
   - Only applicable if power consumption is a concern

### Reliability
7. **SD Card Boot Redundancy**:
   - Keep spare SD card with bootloader
   - Document recovery process
   - Consider dual SD card holders (if available)

8. **UPS**: Uninterruptible Power Supply recommended
   - Protects against power loss during Btrfs writes
   - RAID0 + sudden power loss = high corruption risk

---

## Known Issues and Limitations

### Storage
- **RAID0 Risk**: Single NVMe failure = complete data loss
- **SD Card Endurance**: Limited write cycles (minimize /boot updates)
- **No Hot Spare**: Both NVMe drives required for operation

### Graphics
- **Hybrid Graphics**: Some applications may not respect Prime offload
- **Wayland**: NVIDIA Prime offload can be flaky on Wayland (verify on X11)
- **Power Management**: Fine-grained disabled (higher idle power on NVIDIA GPU)

### Power
- **Battery Health**: Constant charging degrades battery over time
- **High Idle Power**: Performance governor prevents CPU from idling low
- **Lid Behavior**: Ignoring lid switch may confuse some desktop environments

### Thermal
- **Laptop Cooling**: Not designed for 24/7 full load
- **Dust Accumulation**: Closed laptop lid traps heat, dust builds faster
- **Ambient Temperature**: Ensure good ventilation around laptop

### Unknown Compatibility
- **Wi-Fi**: May require additional firmware (Intel ax210/ax211 common)
- **Thunderbolt**: External GPU or storage not tested
- **Display**: Internal panel behavior when lid closed unknown

---

## Verification Checklist

Run these commands on the live system to complete hardware documentation:

### Memory
```bash
free -h
sudo dmidecode -t memory | grep -E 'Size|Speed|Type:|Manufacturer'
lsmem --summary
```

### Laptop Model
```bash
sudo dmidecode -t system
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/sys_vendor
```

### Network Interfaces
```bash
ip link show
lspci | grep -i network
lspci | grep -i ethernet
lspci | grep -i wireless
```

### Display
```bash
xrandr  # If running X11
cat /sys/class/drm/card*/card*/edid | edid-decode  # Requires edid-decode
```

### USB Layout
```bash
lsusb -t
```

### Storage Health
```bash
sudo smartctl -a /dev/nvme0
sudo smartctl -a /dev/nvme1
sudo btrfs filesystem show
sudo btrfs filesystem df /tundra/permafrost
```

### Temperatures/Sensors
```bash
sensors
cat /sys/class/thermal/thermal_zone*/temp
```

---

## References

- **NixOS Configuration**: `/nix/systems/x86_64-linux/zao/default.nix`
- **Disko Configuration**: `/nix/systems/x86_64-linux/zao/disko.nix`
- **Intel ARK**: [i9-11900H Specifications](https://ark.intel.com/content/www/us/en/ark/products/213803/intel-core-i911900h-processor-24m-cache-up-to-4-90-ghz.html)
- **NVIDIA**: [RTX 3060 Mobile Specs](https://www.nvidia.com/en-us/geforce/graphics-cards/30-series/rtx-3060-3060ti/)
- **WD Blue SN570**: [Product Page](https://www.westerndigital.com/products/internal-drives/wd-blue-sn570-nvme-ssd)
- **Btrfs RAID**: [Btrfs Wiki - RAID](https://btrfs.readthedocs.io/en/latest/mkfs.btrfs.html#profiles)

---

*Last Updated: 2025-11-30*
*NixOS State Version: 25.05*
