# AMI Aptio CRB - Hardware Profile

**System Name**: rakku
**Hostname**: rakku
**Scan Date**: 2025-10-28
**Target OS**: NixOS

---

## System Overview

- **Manufacturer**: AMI Corporation
- **Model**: Aptio CRB (Custom Reference Board)
- **Product Family**: White-box/Custom Build
- **Form Factor**: Desktop/Router Appliance (Chassis Type: Desktop)
- **BIOS**: American Megatrends Inc. v5.6.5 (12/26/2018)
- **Serial**: Default string
- **Purpose**: Network Router/Firewall appliance with 4x Gigabit Ethernet

---

## Processor

- **CPU**: Intel Celeron J1900 (Bay Trail-D)
- **Architecture**: x86_64
- **Cores**: 4 cores (no hyperthreading)
- **Threads**: 4 threads
- **Frequency Range**: 1333 MHz - 2416 MHz
- **Base Clock**: 1.99 GHz
- **Turbo Boost**: 2.42 GHz (max)
- **Cache**:
  - L1d: 96 KiB (4 instances, 24 KiB each)
  - L1i: 128 KiB (4 instances, 32 KiB each)
  - L2: 2 MiB (2 instances, 1 MiB each)
- **Features**:
  - SSE4.1, SSE4.2
  - VT-x (Virtualization Technology)
  - Enhanced Intel SpeedStep (EST)
  - RDRAND (Hardware RNG)
- **Frequency Scaling**: intel_pstate driver
- **BogoMIPS**: 4000.00

### CPU Vulnerabilities Status

- Meltdown: Mitigated (PTI)
- Spectre v1: Mitigated (usercopy/swapgs barriers)
- Spectre v2: Mitigated (Retpolines, IBPB conditional, IBRS_FW, STIBP disabled, RSB filling)
- MDS: Mitigated (Clear CPU buffers; SMT disabled)
- L1tf: Not affected
- MMIO stale data: Unknown (no mitigations)

---

## Memory

- **Total RAM**: 8 GB (7972688 kB / 7.6 GiB)
- **Type**: DDR3L (likely, typical for Bay Trail)
- **Configuration**: SO-DIMM (likely)
- **NUMA**: Single node (node0)
- **Swap**: 6 GB (6199056 kB) on disk partition

---

## Storage

### Primary Drive

- **Model**: Hoodisk SSD
- **Capacity**: 60 GB (59.6 GB)
- **Interface**: SATA
- **Device Path**: /dev/sda
- **Rotational**: No (SSD)

### Current Disk Layout

- **Partition 1** (sda1): 512M (EFI System Partition)
  - Filesystem: FAT32 (vfat)
  - Mount: /boot/efi
- **Partition 2** (sda2): 53.2G (Root filesystem)
  - Filesystem: ext4
  - Mount: /
- **Partition 3** (sda3): 5.9G (Swap partition)
  - Type: Linux swap

### Storage Hardware

- **Controller**: Intel SATA Controller (integrated with chipset)
- **SATA Ports**: 2 ports detected

---

## Graphics

### Integrated GPU

- **Model**: Intel HD Graphics (Bay Trail-D)
- **PCI ID**: 0000:00:02.0
- **Driver**: i915 (3.0 MB module)

### Display Outputs (DRM Connectors)

- **card0-VGA-1**: VGA port
- **card0-HDMI-A-1**: HDMI port
- **card0-DP-1**: DisplayPort

### Graphics Notes

- This is a router/firewall appliance - graphics outputs likely unused
- Headless operation recommended
- Outputs available for initial setup/troubleshooting

---

## Audio

### Controller

- **Model**: Intel HD Audio (Bay Trail)
- **PCI ID**: 0000:00:1b.0 (likely)
- **Driver**: snd_hda_intel

### Audio Capabilities

- Minimal audio support (HDMI audio present)
- Not typically used in router/firewall configuration

### Audio I/O

- **HDMI Audio**: Available through HDMI output (pcmC0D3p)
- **Codec**: hwC0D2

---

## Network

This system is purpose-built as a router/firewall with 4 dedicated Gigabit Ethernet ports.

### Ethernet Interfaces

All interfaces use Intel I211 Gigabit Network Connection

#### Interface 1: lan

- **Chipset**: Intel I211 Gigabit Network Connection
- **PCI Vendor/Device**: 0x8086:0x1539
- **Driver**: igb
- **Interface**: lan (altname: enp1s0)
- **MAC Address**: 40:62:31:12:ac:8f
- **IP Configuration**: 192.18.1.1/24 (static)
- **Status**: Down (no carrier)
- **Purpose**: LAN network

#### Interface 2: server

- **Chipset**: Intel I211 Gigabit Network Connection
- **PCI Vendor/Device**: 0x8086:0x1539
- **Driver**: igb
- **Interface**: server (altname: enp2s0)
- **MAC Address**: 40:62:31:12:ac:90
- **Status**: Down (no carrier)
- **Purpose**: Server network segment

#### Interface 3: raiden

- **Chipset**: Intel I211 Gigabit Network Connection
- **PCI Vendor/Device**: 0x8086:0x1539
- **Driver**: igb
- **Interface**: raiden (altname: enp3s0)
- **MAC Address**: 40:62:31:12:ac:91
- **Status**: Down (no carrier)
- **Purpose**: Additional network segment

#### Interface 4: wan

- **Chipset**: Intel I211 Gigabit Network Connection
- **PCI Vendor/Device**: 0x8086:0x1539
- **Driver**: igb
- **Interface**: wan (altname: enp4s0)
- **MAC Address**: 40:62:31:12:ac:92
- **IP Configuration**: 192.168.1.181/24 (DHCP)
- **IPv6**: 2605:b40:1524:e800::2a2/128 (multiple addresses)
- **Status**: Up and running
- **Purpose**: WAN uplink

### VPN Networks

#### Tailscale

- **Interface**: tailscale0
- **Type**: Point-to-point tunnel
- **IP**: 100.112.119.89/32
- **IPv6**: fd7a:115c:a1e0:ab12:4843:cd96:6270:7759/128

#### ZeroTier

- **Interface**: ztc25efy2t
- **Type**: Virtual ethernet
- **IP**: 10.147.19.33/24

### Network Notes

- **No WiFi**: This is a wired-only appliance
- **No Bluetooth**: Not applicable for router/firewall use
- **Quad NIC Design**: Purpose-built for routing/firewall with multiple network segments

---

## Input Devices

N/A - This is a headless router/firewall appliance with no input devices.

---

## Sensors

### Thermal Management

#### Thermal Zones

- **thermal_zone0** (soc_dts0): 35.00°C
- **thermal_zone1** (soc_dts1): 36.00°C

#### Hardware Monitoring (hwmon)

- **hwmon0**: coretemp (CPU temperature)
- **hwmon1**: soc_dts0 (SoC thermal sensor 0)
- **hwmon2**: soc_dts1 (SoC thermal sensor 1)

### Cooling

- Passive cooling (likely fanless or low-speed fan)
- Intel thermal management built into Bay Trail SoC

---

## USB Controllers

### xHCI USB Controllers

1. **USB 2.0/3.0 Controller**: Integrated with Bay Trail SoC
   - Version: USB 3.0
   - Used for potential external devices/updates

### USB Notes

- Minimal USB usage expected in router/firewall configuration
- Available for initial setup, firmware updates, or emergency access

---

## Power Management

### Power Supply

- **Type**: External DC power adapter (likely 12V)
- **Form Factor**: Standard barrel connector

### Thermal Management

- **Passive/Low-noise cooling**: Designed for 24/7 operation
- **TDP**: 10W (Intel Celeron J1900)
- **Thermal Design**: Optimized for continuous operation

### Power Management Features

- **CPU Frequency Scaling**: intel_pstate
- **CPU Idle States**: Multiple C-states supported
- **Runtime PM**: Enabled for most devices

---

## PCI Devices Summary

Based on typical Bay Trail-D platform:

### Critical Devices

- **0000:00:00.0**: Host bridge (Intel Bay Trail)
- **0000:00:02.0**: VGA compatible controller - Intel HD Graphics
- **0000:00:13.0**: SATA controller
- **0000:00:14.0**: USB controller - xHCI
- **0000:00:1b.0**: Audio device - Intel HDA
- **0000:00:1c.x**: PCI bridges (for NICs)
- **0000:00:1f.0**: ISA bridge
- **0000:0x:00.0**: Network controllers - 4x Intel I211 (likely on separate PCI buses)

---

## ACPI & Firmware

### UEFI/BIOS

- **Firmware Type**: UEFI 64-bit
- **Vendor**: American Megatrends Inc.
- **Version**: 5.6.5
- **Release Date**: 12/26/2018
- **EFI Variables**: Available
- **Secure Boot**: Capable (likely disabled for NixOS)

### ACPI Configuration

- **OEM**: AMI
- **Platform**: Bay Trail-D

### ACPI Features

- **Power States**: S0 (idle), S3 (sleep), S4 (hibernate), S5 (shutdown)
- **Thermal Zones**: 2 zones defined
- **Passive Cooling**: Thermal management

---

## Loaded Kernel Modules (Key modules)

### Network

- igb - Intel I211 Gigabit Ethernet driver (4 instances)
- 8021q - VLAN support

### Graphics & Display

- i915 (3.0 MB) - Intel graphics driver
- drm - Direct Rendering Manager

### Platform

- intel_rapl_msr - Power monitoring
- intel_rapl_common - RAPL support
- intel_soc_dts_thermal - Thermal management
- intel_soc_dts_iosf - Thermal IOSF interface
- intel_powerclamp - CPU power clamping
- coretemp - CPU temperature monitoring
- iTCO_wdt - Watchdog timer
- punit_atom_debug - Power unit debug

### Storage

- spi_intel_platform - SPI controller
- spi_intel - SPI driver
- at24 - EEPROM support

### Other

- evdev - Input event interface
- mac_hid - HID emulation
- cmdlinepart - MTD partitioning
- spi_nor - SPI NOR flash
- mtd - Memory Technology Device support

---

## Known Hardware Quirks & Issues

### Known Issues

#### 1. Low Performance CPU

- **Component**: Intel Celeron J1900
- **Note**: This is a low-power CPU (10W TDP) designed for efficiency, not performance
- **Suitability**: Excellent for routing/firewall, not suitable for heavy computation
- **Network Throughput**: Should handle gigabit routing with hardware offload

#### 2. Limited Memory

- **Amount**: 8 GB RAM
- **Note**: Sufficient for routing/firewall but may limit VM hosting
- **Recommendation**: Monitor memory usage under load

#### 3. Older BIOS

- **Date**: December 2018 (6+ years old)
- **Impact**: May lack microcode updates for newer vulnerabilities
- **Recommendation**: Check for BIOS updates from manufacturer

### Platform Notes

#### Router/Firewall Optimization

- **Hardware Offload**: Intel I211 NICs support hardware offload features
- **Network Performance**: 4x Gigabit should handle multi-WAN and VLAN configurations
- **Low Power**: 10W TDP makes this ideal for 24/7 operation
- **Fanless Potential**: May be passively cooled for silent operation

---

## Recommended NixOS Configuration

### Hardware Enablement Priority List

1. **Critical (System Boot & Basic Function)**
   - CPU microcode (intel-microcode)
   - NIC drivers (igb for Intel I211)
   - Storage drivers (SATA)
   - Boot loader configuration

2. **High Priority (Router/Firewall Function)**
   - Network bridge/routing configuration
   - Firewall (nftables/iptables)
   - VLAN support (8021q)
   - Hardware offload features

3. **Medium Priority (Management)**
   - SSH access
   - Monitoring tools
   - Log management

4. **Low Priority (Optional Features)**
   - Graphics (for emergency console)
   - Audio (not needed)
   - USB storage support

### Suggested Kernel Parameters

```nix
boot.kernelParams = [
  # Network performance
  "intel_iommu=on"

  # Console (can be disabled for production)
  "console=tty0"

  # Quiet boot
  "loglevel=4"
];
```

### Required Kernel Modules

```nix
boot.initrd.availableKernelModules = [
  "ahci"          # SATA controller
  "xhci_pci"      # USB 3.0
  "usb_storage"   # USB storage
  "sd_mod"        # SCSI disk
  "sdhci_pci"     # SD card (if present)
];

boot.kernelModules = [
  "igb"           # Intel I211 NICs
  "8021q"         # VLAN support
  "br_netfilter"  # Bridge netfilter
];
```

### Network Configuration

```nix
# Enable IP forwarding
boot.kernel.sysctl = {
  "net.ipv4.ip_forward" = 1;
  "net.ipv6.conf.all.forwarding" = 1;
};

# Network interface configuration
networking = {
  hostName = "rakku";
  useDHCP = false;

  interfaces = {
    wan.useDHCP = true;

    lan = {
      ipv4.addresses = [{
        address = "192.18.1.1";
        prefixLength = 24;
      }];
    };
  };

  firewall.enable = true;
};
```

### Power Management

```nix
# Conservative power management for 24/7 operation
powerManagement.enable = true;

# CPU frequency scaling
powerManagement.cpuFreqGovernor = "ondemand";

# Enable powertop for power optimization
powerManagement.powertop.enable = true;
```

### Hardware Configuration

```nix
# Intel graphics (minimal, for console only)
hardware.opengl = {
  enable = true;
  driSupport = true;
};

# Enable firmware
hardware.enableRedistributableFirmware = true;
```

---

## Testing Checklist

### Basic System

- [ ] System boots successfully
- [ ] SSH access working
- [ ] Console access (if needed)
- [ ] Storage I/O performing well
- [ ] System stable under load

### Network

- [ ] All 4 NICs detected and named correctly
- [ ] WAN interface gets DHCP address
- [ ] LAN interface static IP configured
- [ ] IP forwarding enabled
- [ ] Routing between interfaces works
- [ ] Firewall rules applied correctly
- [ ] NAT/masquerading functional
- [ ] VLAN tagging (if used)
- [ ] Hardware offload features active
- [ ] Network throughput meets expectations

### VPN

- [ ] Tailscale connects and routes
- [ ] ZeroTier connects and routes
- [ ] VPN traffic routed correctly

### Performance

- [ ] CPU usage reasonable under routing load
- [ ] Memory usage acceptable
- [ ] No thermal throttling under load
- [ ] Gigabit speeds achievable on each port
- [ ] Low latency through router

### Stability

- [ ] 24-hour stability test
- [ ] Sustained network load test
- [ ] Memory leak monitoring
- [ ] Log rotation working

---

## References

- **Kernel Version**: 6.1.58 (from running system)
- **NixOS Version**: 23.11 (Tapir) - 20231019
- **Scan Date**: 2025-10-28
- **Scan Method**: SSH remote profiling

## Notes

This is a purpose-built router/firewall appliance based on Intel Bay Trail-D platform with quad Gigabit Ethernet. The low-power Celeron J1900 CPU is well-suited for network routing tasks but not for heavy computation.

Key features:

1. **Quad NIC**: 4x Intel I211 Gigabit Ethernet for multi-segment networks
2. **Low Power**: 10W TDP for efficient 24/7 operation
3. **Fanless Design**: Likely passively cooled for silent operation
4. **VPN Integration**: Already running Tailscale and ZeroTier
5. **Headless**: No need for display/keyboard in production

Recommended use cases:

- Home/small office router
- Multi-WAN gateway
- VPN gateway
- Network firewall
- VLAN router
- Simple packet inspection

Not recommended for:

- Heavy VPN encryption (CPU limited)
- Complex deep packet inspection
- VM hosting (limited RAM/CPU)
- High-throughput workloads (>1 Gbps aggregate)
