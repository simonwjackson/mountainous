# Hardware Profile: GPD G1617-02 (kuji)

This document describes the hardware configuration for the GPD G1617-02 portable gaming device, to be used as the basis for the NixOS host configuration named `kuji`.

## System Overview

**Manufacturer:** GPD
**Model:** G1617-02 (GPD Win Max 2 series)
**Chassis Type:** Laptop/Portable Gaming Device
**BIOS:** Version 2.10 (June 5, 2025)
**Boot Mode:** UEFI
**Architecture:** x86_64

## Processor

**Model:** AMD Ryzen AI 9 HX 370 with Radeon 890M
**Cores:** 12 physical cores / 24 threads (SMT enabled)
**Frequency:** 599 MHz - 4367 MHz
**Cache:**
- L1d: 576 KiB (12 instances)
- L1i: 384 KiB (12 instances)
- L2: 12 MiB (12 instances)
- L3: 24 MiB (2 instances)

**Features:**
- AVX, AVX2, AVX-512
- AMD-V virtualization (kvm_amd)
- AES-NI, SHA-NI
- IBRS, IBPB, STIBP security mitigations

**NixOS Implications:**
- Enable `hardware.cpu.amd.updateMicrocode`
- Consider `boot.kernelModules = [ "kvm-amd" ]` for virtualization
- Modern AMD CPU - latest kernel recommended (6.12+)

## Memory

**Total RAM:** ~24 GB (24,205,752 kB)
**Swap:** None currently configured

**NixOS Implications:**
- Consider enabling swap/zram for better memory management
- 24GB is sufficient for most workloads without swap

## Storage

**Primary Drive:** KIOXIA EXCERIA PLUS G3 NVMe SSD
**Capacity:** 1.8 TB
**Serial:** 6FAKS1DUZ0E8
**Device Path:** `/dev/nvme0n1`
**by-id Path:** `nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_6FAKS1DUZ0E8`
**PCIe Address:** `pci-0000:c1:00.0-nvme-1`

**Current Partition Table (Windows):**
```
nvme0n1p1    100M   (EFI System Partition)
nvme0n1p2    128M   (Microsoft Reserved)
nvme0n1p3    300G   (NTFS - Windows C:)
nvme0n1p4    1.5T   (NTFS - Windows D:)
nvme0n1p5     16G   (NTFS - Recovery)
```

**NixOS Implications:**
- EFI partition exists at nvme0n1p1 - can be reused or recreated
- NVMe drive requires `boot.initrd.availableKernelModules = [ "nvme" ]`
- Consider full repartition or dual-boot configuration
- High-performance SSD - enable TRIM: `services.fstrim.enable = true`

## Graphics

**GPU:** AMD Radeon 880M / 890M (Strix integrated graphics)
**Vendor ID:** 0x1002 (AMD/ATI)
**Device ID:** 0x150e
**PCI Address:** c4:00.0
**Driver:** amdgpu
**VRAM:** 256MB dedicated (plus shared system RAM)
**DRI Devices:** card1, renderD128

**NixOS Implications:**
- Use `boot.initrd.kernelModules = [ "amdgpu" ]` for early KMS
- Enable `hardware.graphics.enable = true` (replaces deprecated opengl)
- AMD Strix is RDNA 3.5 - requires Mesa 24.0+ and kernel 6.9+
- For Vulkan: `hardware.graphics.enable32Bit = true` (if using Wine/gaming)
- May need `hardware.amdgpu.opencl.enable = true` for compute tasks
- Consider `services.xserver.videoDrivers = [ "amdgpu" ]` for X11

## Network

**Wi-Fi Adapter:** Intel Wi-Fi 6E AX210/AX1675 (Typhoon Peak)
**PCI Address:** c3:00.0
**PCI ID:** 8086:2725
**Driver:** iwlwifi
**Interface:** wlp195s0
**MAC Address:** ac:45:ef:96:49:61
**Capabilities:** 802.11ax (Wi-Fi 6E), 2.4/5/6 GHz

**Bluetooth:** Intel AX210 Bluetooth (integrated with Wi-Fi card)

**NixOS Implications:**
- Enable `hardware.enableRedistributableFirmware = true` for iwlwifi firmware
- Or specifically: `hardware.firmware = [ pkgs.linux-firmware ]`
- Bluetooth: `hardware.bluetooth.enable = true`
- NetworkManager recommended: `networking.networkmanager.enable = true`
- Wi-Fi interface name: wlp195s0 (predictable naming)

## Audio

**Controllers:**
1. AMD Rembrandt Radeon HD Audio (c4:00.1) - HDMI/DisplayPort audio
2. AMD Family 17h/19h/1ah HD Audio (c4:00.6) - Analog audio

**Sound Cards:**
- Card 0: HD-Audio Generic (snd_hda_intel)
- Card 1: HD-Audio Generic (snd_hda_intel)

**Audio Server:** PipeWire 1.4.7 with WirePlumber (currently running)

**NixOS Implications:**
- Enable PipeWire: `services.pipewire.enable = true`
- With ALSA, PulseAudio, and JACK compatibility:
  ```nix
  services.pipewire.alsa.enable = true;
  services.pipewire.pulse.enable = true;
  services.pipewire.jack.enable = true;
  ```
- Kernel modules: `snd_hda_intel` (loaded automatically)

## USB & Thunderbolt

**USB Controllers:**
- c4:00.4: AMD XHCI USB 3.0 controller
- c6:00.0: AMD XHCI USB 3.0 controller
- c6:00.3: AMD XHCI USB 3.0 controller
- c6:00.4: AMD XHCI USB 3.0 controller
- c6:00.5: AMD USB4/Thunderbolt Host Interface
- c6:00.6: AMD USB4/Thunderbolt Host Interface

**NixOS Implications:**
- USB support enabled by default
- For USB4/Thunderbolt: `services.hardware.bolt.enable = true`
- Multiple USB controllers provide ample connectivity

## Input Devices

**Keyboard:** AT Translated Set 2 keyboard (built-in PS/2)

**Touchpads:**
1. NVTK0603:00 (i2c-NVTK0603:00)
2. HTIX5288:00 0911:5288 (i2c-HTIX5288:00)

**Other:**
- Power Button (ACPI)
- Lid Switch (ACPI)
- Video Bus controls

**NixOS Implications:**
- Enable libinput for touchpad: `services.libinput.enable = true`
- I2C touchpads may need: `boot.initrd.availableKernelModules = [ "i2c_hid" "i2c_hid_acpi" ]`
- Consider touchpad configuration in libinput settings
- Lid switch handled by systemd-logind

## Thermal & Power Management

**Thermal Zones:**
- acpitz (ACPI thermal)
- iwlwifi_1 (Wi-Fi module)

**Hardware Monitors:**
- hwmon0: nvme (NVMe drive temperature)
- hwmon1: ACAD (AC adapter)
- hwmon2: k10temp (AMD CPU temperature)
- hwmon3: acpitz (ACPI thermal zone)
- hwmon4: BATT (Battery)
- hwmon5: iwlwifi_1 (Intel WiFi module)
- hwmon6: amdgpu (AMD GPU temperatures)

**Power Supply:** Battery + AC adapter
**Lid Sensor:** Present

**NixOS Implications:**
- Enable TLP or auto-cpufreq for laptop power management:
  ```nix
  services.tlp.enable = true;
  # OR
  services.auto-cpufreq.enable = true;
  ```
- Enable thermal management: `services.thermald.enable = true` (Intel-focused, may skip)
- AMD P-State driver: Consider `boot.kernelParams = [ "amd_pstate=active" ]` for better power management
- Battery optimization: `powerManagement.enable = true`

## Special Hardware

**Neural Processing Unit (NPU):** AMD Strix/Krackan NPU (c5:00.1)
**Co-processor Type:** 0b40

**Security Processor:** AMD CCP/ASP (c4:00.2)
**Encryption Controller:** 1080

**Sensor Fusion Hub:** AMD SFH (c4:00.7)
**Controller Type:** 0480

**NixOS Implications:**
- NPU support in Linux is emerging - may require proprietary drivers
- CCP/ASP provides hardware crypto - enabled automatically
- Sensor Fusion Hub for accelerometer/gyro (gaming device feature)

## Kernel Configuration

**Current Kernel:** Linux 6.12.55
**Key Modules:**
- amdgpu (graphics)
- iwlmvm, iwlwifi (wireless)
- snd_hda_intel (audio)
- kvm_amd (virtualization)
- xpad (Xbox controller support)
- nvme (NVMe storage)

**Boot Parameters:**
- elevator=noop (deprecated, use none)
- nohibernate
- lsm=landlock,yama,bpf

**NixOS Implications:**
```nix
boot.initrd.availableKernelModules = [
  "nvme"
  "xhci_pci"
  "thunderbolt"
  "usb_storage"
  "sd_mod"
  "sdhci_pci"
];

boot.initrd.kernelModules = [ "amdgpu" ];

boot.kernelModules = [ "kvm-amd" ];

boot.kernelParams = [
  # Modern scheduler, no need for elevator param
  "amd_pstate=active"  # Better AMD power management
  # Gaming optimizations (optional):
  # "mitigations=off"  # Disable security mitigations for performance (use with caution)
];
```

## Complete PCI Device Tree

```
c0:00.0 Host bridge: AMD Strix/Strix Halo Root Complex
c0:00.2 IOMMU: AMD IOMMU [1022:14e9]
c0:01.1 PCI bridge: AMD USB4 bridge [1022:14ee]
c0:01.2 PCI bridge: AMD USB4 bridge [1022:14ee]
c0:02.1 PCI bridge: AMD GPP bridge [1022:14ee]
c0:02.2 PCI bridge: AMD GPP bridge [1022:14ee]
c0:02.3 PCI bridge: AMD GPP bridge [1022:14ee]
c0:08.1 PCI bridge: AMD internal GPP bridge [1022:14ee]
c0:08.3 PCI bridge: AMD internal GPP bridge [1022:14ee]
c0:14.0 SMBus: AMD SMBus controller [1022:790b]
c0:14.3 ISA bridge: AMD LPC bridge [1022:790e]
c0:18.0-c0:18.7 Host bridge: AMD Data Fabric controllers [1022:14ed]

c1:00.0 NVMe: KIOXIA EXCERIA PLUS G3 SSD [1e0f:0027]
c3:00.0 Network: Intel Wi-Fi 6E AX210 [8086:2725]

c4:00.0 Display: AMD Radeon 880M/890M [1002:150e]
c4:00.1 Audio: AMD Rembrandt Radeon HD Audio [1002:1640]
c4:00.2 Encryption: AMD CCP/ASP [1022:15df]
c4:00.4 USB: AMD XHCI USB 3.0 [1022:15b6]
c4:00.6 Audio: AMD Family 17h/19h/1ah HD Audio [1022:15e3]
c4:00.7 Non-VGA: AMD Sensor Fusion Hub [1022:15e6]

c5:00.1 Co-processor: AMD Strix/Krackan NPU [1022:1502]

c6:00.0 USB: AMD XHCI [1022:15b6]
c6:00.3 USB: AMD XHCI [1022:15b6]
c6:00.4 USB: AMD XHCI [1022:15b6]
c6:00.5 USB: AMD USB4/Thunderbolt [1022:1668]
c6:00.6 USB: AMD USB4/Thunderbolt [1022:1668]
```

## Recommended NixOS Hardware Configuration Template

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration
  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
        "i2c_hid"
        "i2c_hid_acpi"
      ];
      kernelModules = [ "amdgpu" ];
    };

    kernelModules = [ "kvm-amd" ];
    kernelParams = [
      "amd_pstate=active"
    ];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Hardware support
  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      enable32Bit = true;  # For gaming/Wine
    };

    bluetooth.enable = true;
  };

  # Services
  services = {
    fstrim.enable = true;  # SSD optimization

    # Power management
    tlp.enable = true;

    # Thunderbolt
    hardware.bolt.enable = true;

    # Input
    libinput.enable = true;

    # Audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };

  # Networking
  networking.networkmanager.enable = true;

  # Power management
  powerManagement.enable = true;
}
```

## Notes

- **Kernel Version:** Requires Linux 6.9+ for full AMD Strix GPU support, 6.12+ recommended
- **Gaming Device:** Consider gamemode, gamescope, and Steam optimizations
- **Dual Boot:** Current Windows installation - plan NixOS partitioning strategy
- **Battery Life:** Portable device - power management critical (TLP/auto-cpufreq)
- **Display:** Built-in display specs not captured - check resolution/refresh rate
- **Controllers:** xpad module loaded - Xbox controller support for gaming
- **NPU:** Emerging Linux support - may require future configuration updates

## Future Hardware Information Needed

- Built-in display specifications (resolution, refresh rate, panel type)
- Battery capacity and expected runtime
- Keyboard backlight capabilities
- SD card reader specifications (if present)
- Webcam specifications
- Gaming controls layout (if device has built-in game controllers)
