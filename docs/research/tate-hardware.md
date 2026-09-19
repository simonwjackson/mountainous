# Tate (Intel Celeron J4105 Mini PC) - Hardware Profile

**Host Name**: tate
**Profile Date**: 2026-09-19
**Scan Origin**: Scanned live via Hiyori portable USB boot on Tailscale (`100.84.190.3`)
**Target OS**: NixOS 26.11 (Zokor), Linux kernel 6.18.51 x86_64

---

## Executive Summary

The target device is an Intel Gemini Lake desktop mini PC manufactured by Shenzhen CYX Technology Co., Ltd. (ODM for Beelink and similar Gemini Lake mini PCs). It features an Intel Celeron J4105 quad-core processor, Intel UHD Graphics 600, 4 GiB LPDDR4 memory, and a 64 GB Samsung eMMC 5.1 internal storage module. All core onboard peripherals (Gigabit Ethernet, Intel 802.11ac Wi-Fi, Intel Bluetooth, Realtek ALC269VC audio, dual HDMI video) are supported by mainline Linux drivers without proprietary vendor blobs.

### Quick Reference

| Component | Hardware Identity | Driver / Subsystem | Status |
|---|---|---|---|
| Processor | Intel Celeron J4105 @ 1.50 GHz (Gemini Lake, 4C/4T) | `intel_cpufreq` (800–2500 MHz) | Verified working |
| Memory | 4 GiB (2 × 2 GiB) LPDDR4 @ 2400 MT/s | Single NUMA node, 3.6 GiB usable | Verified working |
| Internal Disk | Samsung CGND3R 64 GB eMMC 5.1 (`/dev/mmcblk1`, 58.2 GiB) | `sdhci_pci` / `mmc_block` | Verified present, 0–10% wear |
| Graphics | Intel UHD Graphics 600 (`8086:3185`, rev 03) | `i915`, DMC v1.04 firmware | Verified working |
| Display Out | 2 × HDMI (HDMI-A-1, HDMI-A-2) | DRM card0 (HDMI-A-2 connected) | Verified working (2880×1800@100Hz) |
| Audio | Intel HDA PCH (`8086:3198`) + Realtek ALC269VC | `snd_hda_intel`, `snd_hda_codec_realtek` | Verified detected |
| Ethernet | Realtek RTL8111/8168/8411 Gigabit Ethernet (`10ec:8168`) | `r8169`, firmware `rtl8168e-3_0.0.4` | Verified active (1000 Mb/s) |
| Wi-Fi | Intel Dual Band Wireless-AC 3165 (`8086:3165`, rev 91) | `iwlwifi`, firmware `7265D-29.ucode` | Verified loaded, unblocked |
| Bluetooth | Intel Bluetooth USB (`8087:0a2a`) | `btusb`, firmware `ibt-hw-37.8.10` | Verified active, unblocked |
| Card Reader | Realtek RTS5129 Card Reader (`0bda:0129`) | `rtsx_usb` | Verified detected |
| Power | External DC Mains Adapter (`ADP1`) | ACPI Mains | Verified active |
| Firmware | AMI Aptio V v5.13 (2019-09-30), UEFI + Legacy CSM | DMI / ACPI 6.2 | Booted in Legacy BIOS mode |

---

## System Overview

- **Manufacturer (ODM)**: Shenzhen CYX Technology Co., Ltd. (OUI `68:1d:ef`)
- **DMI System Information**:
  - Manufacturer: `Default string`
  - Product Name: `Default string`
  - Version: `Default string`
  - Serial Number: `Default string`
  - UUID: `03000200-0400-0500-0006-000700080009`
  - Chassis Type: 3 (Desktop)
- **Baseboard**:
  - Manufacturer: `Default string`
  - Product Name: `Default string`
  - Onboard Devices: Video (`00:02.0`), Realtek Ethernet (`05:00.0`), Intel Audio (`00:0e.0`), Intel SATA (`00:12.0`)
- **Firmware / BIOS**:
  - Vendor: American Megatrends Inc. (AMI)
  - Version: 5.13
  - Release Date: 09/30/2019
  - Characteristics: PCI, BIOS boot spec, ACPI, USB legacy, UEFI supported
  - TPM: TPM 2.0 device present in ACPI table (`TPM2`)
  - Boot State: Booted under Legacy BIOS (CSM) via Hiyori GRUB MBR. `/sys/firmware/efi` was not populated during this scan.

---

## Processor

- **Model**: Intel Celeron J4105 CPU @ 1.50 GHz (Gemini Lake)
- **Architecture**: `x86_64` (Family 6, Model 122 / 0x7a, Stepping 1)
- **Topology**: 4 physical cores, 4 threads (1 thread/core, 1 socket)
- **Frequency**:
  - Base: 1.50 GHz (800 MHz min)
  - Burst: 2.50 GHz max
  - Scaling Driver: `intel_cpufreq`
  - Active Governor: `schedutil`
  - Transition Latency: 20 µs
- **Caches**:
  - L1 Data: 96 KiB (4 × 24 KiB)
  - L1 Instruction: 128 KiB (4 × 32 KiB)
  - L2: 4 MiB (unified)
- **Virtualization**: Intel VT-x (`vmx`)
- **Security Mitigations**:
  - Microcode revision: `0x42`
  - Meltdown: Mitigated (PTI)
  - Spectre v1: Mitigated (usercopy/swapgs barriers)
  - Spectre v2: Mitigated (Enhanced / Automatic IBRS, IBPB conditional)
  - Speculative Store Bypass: Mitigated (prctl)
  - MDS, L1TF, Retbleed, MMIO Stale Data, GDS: Not affected

---

## Memory

- **Total Usable RAM**: 3.6 GiB (3790 MiB)
- **Configuration**:
  - Array Maximum Capacity: 64 GiB
  - Installed Devices: 2 modules (Channel A1_DIMM0 and A1_DIMM1)
  - Capacity: 2 GiB per channel (4 GiB total)
  - Technology: LPDDR4 Synchronous DRAM
  - Speed: 2400 MT/s (configured 2400 MT/s)
  - Voltage: 1.1 V
  - Form Factor: Soldered DIMM

---

## Storage Subsystems

### Internal eMMC Storage (`/dev/mmcblk1`)
- **Controller**: Intel Gemini Lake SD Host Controller (PCI `0000:00:1e.0` [8086:31d0])
  - Driver: `sdhci_pci`, `mmc_block`
- **Device Node**: `/dev/mmcblk1`
- **Persistent By-ID**: `/dev/disk/by-id/mmc-CGND3R_0x96f945e3`
- **Manufacturer**: Samsung Electronics (`manfid: 0x000015`)
- **Product Name**: `CGND3R` (eMMC 5.1)
- **Capacity**: 58.24 GiB (62,537,072,640 bytes, 122,142,720 sectors @ 512B)
- **Hardware Health**:
  - `life_time`: `0x01 0x01` (0%–10% device lifetime used)
  - `pre_eol_info`: `0x01` (Normal)
  - `rev`: `0x7` (eMMC 5.1)
  - Serial: `0x96f945e3`
- **Current Partition State**: Raw DOS disklabel (`0xfbde8b48`) with 0 partitions defined. Ready for partitioning.
- **Boot Partitions**: `mmcblk1boot0` (4 MiB) and `mmcblk1boot1` (4 MiB) hardware RPMB/boot areas present.

### Secondary Storage Controller
- **SATA Controller**: Intel Gemini Lake AHCI SATA Controller (PCI `0000:00:12.0` [8086:31e3])
  - Driver: `ahci`
  - Status: Enabled; available for internal SATA/M.2 SATA expansion if a slot is populated.
- **SD Controller**: Intel Gemini Lake SDA Standard SD Host Controller (PCI `0000:00:1c.0` [8086:31cc])
  - Status: Empty card slot (`mmc0: Failed to initialize a non-removable card` on boot).
- **USB Card Reader**: Realtek RTS5129 Card Reader (`0bda:0129`)
  - Driver: `rtsx_usb`

---

## Graphics and Displays

### Integrated GPU
- **Model**: Intel Corporation GeminiLake [UHD Graphics 600]
- **PCI ID**: `0000:00:02.0` (`8086:3185`, rev 03)
- **Driver**: `i915`
- **Firmware**: `i915/glk_dmc_ver1_04.bin` (v1.4 loaded successfully)
- **DRM Nodes**: `/dev/dri/card0`, `/dev/dri/renderD128`

### Display Outputs
- **Connector 1**: `card0-HDMI-A-1` (Disconnected)
- **Connector 2**: `card0-HDMI-A-2` (Connected and active)
  - Attached Monitor: `EM160TP-A` (16-inch 16:10 OLED display, serial 1)
  - Native Resolution: 2880×1800 @ 99.998 Hz
  - Alternative Valid Modes: 2560×1600 @ 60/120 Hz, 2560×1440 @ 60/120 Hz, 1920×1200 @ 60 Hz, 1920×1080 @ 60/120 Hz
  - Audio: Linear PCM stereo (32, 44.1, 48, 88.2, 96 kHz @ 16/20/24-bit)
  - Colorimetry: BT2020RGB, BT2020YCC, HDR static metadata supported

---

## Audio Subsystem

- **HDA Controller**: Intel Celeron/Pentium Silver Processor High Definition Audio (`8086:3198`, rev 03)
  - PCI Address: `0000:00:0e.0`
  - Driver: `snd_hda_intel` (IRQ 135)
- **Analog Codec**: Realtek ALC269VC (`10ec:0269`, rev `0x100203`)
  - Subsystem ID: `10ec:0269`
  - Playback / Capture: ALC269VC Analog (device 0)
  - Outputs: Headphone jack (front) and internal PC Beep
- **Digital Codec**: Intel Gemini Lake HDMI Audio
  - Card 0 Device 3: HDMI 0 (`EM160TP-A` display audio)
  - Card 0 Device 7: HDMI 1
  - Card 0 Device 8: HDMI 2

---

## Networking

### Gigabit Ethernet (`enp5s0`)
- **Controller**: Realtek RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet (`10ec:8168`, rev 07)
  - PCI Address: `0000:05:00.0`
  - Driver: `r8169`
  - Firmware: `rtl8168e-3_0.0.4 03/27/12`
  - MAC Address: `68:1d:ef:18:a2:e1` (Shenzhen CYX Technology Co., Ltd.)
  - Link Status: Up at 1000 Mb/s Full Duplex (autonegotiated)
  - Local IP: `192.168.1.189/24`

### Wireless LAN (`wlp6s0`)
- **Controller**: Intel Dual Band Wireless-AC 3165 (`8086:3165`, rev 91)
  - PCI Address: `0000:06:00.0`
  - Driver: `iwlwifi`
  - Firmware: `iwlwifi-7265D-29.ucode` (API version 29)
  - Permanent MAC: `50:eb:71:4d:e3:29`
  - State: Unblocked by rfkill; capable of 802.11a/b/g/n/ac

### Bluetooth (`hci0`)
- **Controller**: Intel Bluetooth wireless interface (`8087:0a2a`)
  - Bus: USB 1-4 (Port 4 of root hub 1)
  - Driver: `btusb`
  - Firmware: `intel/ibt-hw-37.8.10-fw-1.10.3.11.e.bseq`
  - State: Unblocked by rfkill

---

## Power and Thermal Management

- **Power Supply**: External AC-DC power adapter (`ADP1`, Mains power)
- **TDP**: 10 W (Intel Celeron J4105)
- **Thermal Zones**:
  - `thermal_zone0`: `iwlwifi_1` (39.0 °C)
  - `thermal_zone1`: `INT3400 Thermal` (20.0 °C)
  - `thermal_zone6`: `acpitz` (48.0 °C)
  - `thermal_zone7`: `TCPU` (49.0 °C)
  - `thermal_zone8`: `x86_pkg_temp` (49.0 °C)
- **Power States**: S0 (working), S3 (suspend to RAM), S4 (hibernate), S5 (shutdown) supported.

---

## Known Hardware Quirks and Workarounds

### 1. eMMC Controller in Initrd
The internal disk is on an SDHCI controller (`0000:00:1e.0 [8086:31d0]`). Standard NixOS `base` initrd kernel modules include `nvme` and `ahci`, but omit `sdhci_pci` and `mmc_block`.
- **Required Fix**: Add `"sdhci_pci"` and `"mmc_block"` to `boot.initrd.availableKernelModules`.

### 2. Dual BIOS / UEFI Boot Support
The AMI Aptio V firmware supports both UEFI and Legacy BIOS CSM. During USB testing, the machine booted under Legacy BIOS.
- **Recommended Fix**: Use `mountainous.disk.biosBoot = true` in Disko to include a 1M EF02 partition alongside the 1G ESP. Use GRUB with `efiSupport = true` and `efiInstallAsRemovable = true` so the system boots whether UEFI or Legacy BIOS is selected.

### 3. ACPI Thermal Sensor Symbol Warning
The AMI ACPI tables reference an unpopulated embedded controller symbol in thermal zone 5 (`\_SB.PCI0.SBRG.HEC.TSR4` / `SEN4._TMP`).
- **Impact**: Emits cosmetic warnings in `dmesg` (`Could not resolve symbol ... Temperature check failed (-5)`). Core thermal zones (`TCPU` at 49 °C and `x86_pkg_temp`) function correctly. No operational impact.

### 4. PCIe Bridge Retraining Warnings
PCIe root ports 13.0, 13.1, 13.2, 13.3 report `retraining failed` on boot.
- **Impact**: These are unpopulated internal PCIe lanes on the SoC. Completely harmless.

---

## Proposed NixOS Host Configuration

### Hardware Layer (`modules/gemini-lake.nix`)
```nix
{
  nixos.modules.gemini-lake =
    { pkgs, ... }:
    {
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;

      boot.initrd.availableKernelModules = [
        "sdhci_pci"
        "mmc_block"
        "ahci"
        "r8169"
      ];

      boot.initrd.kernelModules = [ "i915" ];

      boot.kernelModules = [
        "iwlwifi"
        "btusb"
        "r8169"
        "snd_hda_intel"
        "rtsx_usb"
      ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
          libvdpau-va-gl
        ];
      };

      hardware.bluetooth.enable = true;
      services.acpid.enable = true;
      services.thermald.enable = true;

      # Dual UEFI / BIOS boot capability for AMI Aptio firmware
      boot.loader.systemd-boot.enable = false;
      boot.loader.efi.canTouchEfiVariables = false;
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/disk/by-id/mmc-CGND3R_0x96f945e3";
      };

      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        ethtool
      ];
    };
}
```

### Host Definition (`modules/hosts/tate.nix`)
```nix
{
  nixos.hosts.tate = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
      "disk"
      "gemini-lake"
    ];

    module = {
      mountainous.disk.device = "/dev/disk/by-id/mmc-CGND3R_0x96f945e3";
      mountainous.disk.biosBoot = true;
    };
  };
}
```
