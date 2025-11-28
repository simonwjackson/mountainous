# Huawei MateBook E (DRC-W56) Hardware Profile

**Date Profiled:** 2025-11-27
**NixOS Installer Version:** 25.05 "Warbler"
**Kernel:** 6.12.55

---

## Executive Summary

The Huawei MateBook E (DRC-W56) is a 12.6" OLED 2-in-1 tablet/laptop with Intel 11th Gen Tiger Lake processor. While the hardware is well-detected by Linux, there is a **critical i915 graphics driver issue** that may require workarounds.

### Quick Reference

| Component | Status | Notes |
|-----------|--------|-------|
| CPU | ✅ Working | Intel i5-1130G7, full support |
| Memory | ✅ Working | 16GB LPDDR4x |
| Storage | ✅ Working | 512GB NVMe SSD |
| WiFi | ✅ Working | Intel AX201, iwlwifi driver |
| Bluetooth | ✅ Working | Intel AX201 integrated |
| GPU | ⚠️ Issues | i915 driver may crash - see workarounds |
| Touchscreen | ✅ Detected | HID 12d1:10b8 multitouch |
| Stylus | ✅ Detected | Pressure-sensitive pen input |
| Rotation Sensors | ✅ Working | Full IIO sensor suite |
| Audio | ✅ Working | Conexant CX11970 via SOF |
| Battery | ✅ Working | 42Wh, charge thresholds supported |
| Cameras | ❓ Unknown | IPU6 detected, untested |

---

## Hardware Specifications

### CPU

- **Model:** Intel Core i5-1130G7 (11th Gen Tiger Lake)
- **Cores/Threads:** 4 cores / 8 threads
- **Base Frequency:** 1.10 GHz
- **Max Turbo:** 4.0 GHz
- **Cache:** L1d 192KB, L1i 128KB, L2 5MB, L3 8MB
- **Architecture:** x86_64
- **Virtualization:** VT-x enabled (KVM ready)

**Notable Features:**
- AVX-512 instruction set
- AES-NI hardware encryption
- Intel TSX (Transactional Memory)
- Hardware P-States (HWP) for power management

**Security Mitigations:**
- Spectre v1/v2: Mitigated
- Meltdown: Not affected
- MDS/L1TF: Not affected

### Memory

- **Total:** 16 GB LPDDR4x
- **Available:** ~15.4 GB to userspace
- **NUMA:** Single node (all cores unified)

### Storage

**Primary Drive:**
- **Device:** `/dev/nvme0n1`
- **Model:** PCIe-8 SSD 512GB
- **Serial:** YMA1512JA214122LHB
- **Capacity:** 476.9 GB
- **Disk ID for disko:** `nvme-PCIe-8_SSD_512GB_YMA1512JA214122LHB`

**Current Partitions (Windows installation):**
| Partition | Size | Type | Description |
|-----------|------|------|-------------|
| nvme0n1p1 | 100M | vfat | EFI System |
| nvme0n1p2 | 16M | - | Microsoft Reserved |
| nvme0n1p3 | 476.3G | ntfs | Windows OS |
| nvme0n1p4 | 546M | ntfs | Recovery |

### Graphics

- **GPU:** Intel Iris Xe Graphics (Tiger Lake-UP4 GT2)
- **Driver:** i915 (loaded)
- **Alternative Driver:** xe (available)
- **Backlight Control:** `intel_backlight`

**⚠️ Known Issue:** The i915 driver has reported issues with DSI panel timing on MateBook E devices. If you experience boot crashes or black screens, add `nomodeset` or `i915.modeset=0` to kernel parameters as a workaround (disables GPU acceleration).

### Display

- **Size:** 12.6" OLED
- **Resolution:** 2560 x 1600 (16:10)
- **Brightness:** 400 nits (600 peak)
- **Touch:** Yes, multitouch
- **Stylus:** Yes, pressure-sensitive

### Network

**WiFi:**
- **Chipset:** Intel Wi-Fi 6 AX201
- **Interface:** wlp0s20f3
- **Driver:** iwlwifi/iwlmvm
- **Firmware:** iwlwifi-22000 (from linux-firmware)
- **Status:** Working

**Ethernet:** None (WiFi only device)

**Bluetooth:**
- **Chipset:** Intel AX201 (integrated)
- **Interface:** hci0
- **Driver:** btusb
- **Status:** Working, unblocked

### Audio

- **Controller:** Intel Tiger Lake-LP Smart Sound (SST)
- **Codec:** Conexant CX11970
- **Card:** sof-hda-dsp
- **Sample Rates:** 48kHz, 96kHz, 192kHz
- **Bit Depths:** 16-bit, 24-bit

**Outputs:**
- Stereo speakers
- 3.5mm headphone jack
- HDMI audio (via USB-C)

### Input Devices

**Touchscreen:**
- **Device:** HID 12d1:10b8
- **Handler:** event2, mouse0
- **Dimensions:** 272mm x 170mm
- **Multitouch:** Yes

**Stylus/Pen:**
- **Device:** HID 12d1:10b8 Stylus
- **Handler:** event3
- **Features:** Pressure sensitivity, tilt detection

**Touchpad:**
- **Device:** HID 12d1:10b8 Touchpad
- **Handler:** event16
- **Gestures:** Supported

### Sensors (IIO)

| Sensor | Type | Purpose |
|--------|------|---------|
| iio:device0 | als | Ambient Light Sensor |
| iio:device1 | als | Secondary Light Sensor |
| iio:device2 | gravity | Gravity detection |
| iio:device3 | relative_orientation | Screen rotation |
| iio:device4 | gyro_3d | Angular velocity |
| iio:device5 | accel_3d | Accelerometer |

**Kernel Modules:**
- hid_sensor_rotation
- hid_sensor_gyro_3d
- hid_sensor_accel_3d
- hid_sensor_als
- hid_multitouch

### Power Management

**Battery:**
- **Model:** HB458816ECW-31T (Desay)
- **Capacity:** 42Wh (design), ~38Wh (current)
- **Health:** 91.2% after 47 cycles
- **Voltage:** 12.645V
- **Charging:** 65W USB-C

**Charge Thresholds:**
- Start: 75%
- End: 80%
- **Note:** Thresholds are configurable via huawei-wmi

**Sleep States:**
- `freeze` - Suspend to idle
- `mem` - Suspend to RAM
- Hibernate: Not supported (disabled in kernel cmdline)

### USB & Connectivity

**USB Controllers:**
- USB 2.0 (480Mbps) - 12+ ports
- USB 3.0 SuperSpeed+ (10Gbps) - 4 ports

**Thunderbolt 4:**
- Full TB4 support via USB-C port
- PCIe tunneling
- DisplayPort Alt Mode
- USB-PD charging

**Cameras:**
- Intel IPU6 Image Processing Unit detected
- 64 video device nodes (`/dev/video0-63`)
- Front: 8MP
- Rear: 13MP
- **Status:** Untested, may require additional configuration

### Fingerprint Reader

- **Device:** Shenzhen Goodix Technology (27c6:5105)
- **Status:** Detected, may require fprintd configuration

---

## System Identification

| Property | Value |
|----------|-------|
| Vendor | HUAWEI |
| Product Name | MateBook E |
| Product SKU | DRC-WXX |
| Product Family | C100 |
| Product Version | M1010 |
| Board Name | DRC-WXX-PCB |
| BIOS Version | 1.35 |
| BIOS Date | 10/26/2023 |
| Chassis Type | 32 (Tablet) |
| Serial | QCFYQ22124Y00380 |

---

## NixOS Hardware Configuration

The following was generated by `nixos-generate-config`:

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "uas"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

---

## Recommended NixOS Configuration

```nix
{ config, pkgs, lib, ... }:

{
  # Boot configuration
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      # Uncomment if experiencing i915 crashes (disables GPU acceleration)
      # "nomodeset"
      # "i915.modeset=0"
    ];

    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "uas"
      "usbhid"
      "sd_mod"
    ];

    kernelModules = [
      "kvm-intel"
      # Sensor modules (usually auto-loaded)
      "hid_sensor_rotation"
      "hid_sensor_accel_3d"
      "hid_sensor_gyro_3d"
      "hid_sensor_als"
    ];

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  # Hardware support
  hardware = {
    enableAllFirmware = true;
    cpu.intel.updateMicrocode = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    wireless.iwd.enable = false; # Use NetworkManager's backend
  };

  # Audio (PipeWire recommended for SOF)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Power management
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Battery charge thresholds (via huawei-wmi)
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Tablet/touchscreen support
  services.libinput.enable = true;

  # Auto-rotation (if using Hyprland/Wayland)
  # mountainous.auto-rotate.enable = true;

  # Fingerprint (optional)
  # services.fprintd.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
```

---

## Known Issues & Workarounds

### 1. Graphics Driver Crashes

**Symptom:** Black screen or system freeze during boot

**Workaround:** Add to kernel parameters:
```nix
boot.kernelParams = [ "nomodeset" ];
# or
boot.kernelParams = [ "i915.modeset=0" ];
```

**Note:** This disables GPU acceleration. Monitor kernel updates for fixes.

### 2. Screen Orientation

**Issue:** Default orientation may be portrait

**Solution:** Configure in window manager (Hyprland/Sway) or use `wlr-randr`

### 3. Hibernate Not Supported

**Issue:** Hibernate disabled in firmware/kernel

**Note:** Suspend to RAM (`mem`) works fine

---

## Disk IDs for Installation

When configuring disko or filesystem mounts, use these persistent identifiers:

```nix
# Primary NVMe SSD
disk = "/dev/disk/by-id/nvme-PCIe-8_SSD_512GB_YMA1512JA214122LHB";
```

---

## Additional Resources

- [Arch Wiki - Huawei](https://wiki.archlinux.org/title/Category:Huawei)
- [NixOS Hardware Database](https://github.com/NixOS/nixos-hardware)
- [Intel i915 Driver](https://www.kernel.org/doc/html/latest/gpu/i915.html)
- [Huawei WMI Driver](https://github.com/aymanbagabas/Huawei-WMI)

---

## Raw Data Sources

This profile was generated via SSH to the NixOS installer at 192.168.1.135 using:
- `lscpu`, `lspci`, `lsusb`, `lsblk`
- `/proc/cpuinfo`, `/proc/meminfo`, `/proc/bus/input/devices`
- `/sys/class/` subsystems (power_supply, backlight, dmi, iio)
- `nixos-generate-config --show-hardware-config`
- `nvme list`, `rfkill list`, `ip link show`
