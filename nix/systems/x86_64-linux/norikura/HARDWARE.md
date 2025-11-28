# GPD Pocket 2 NixOS Setup Plan

## Device Profile
- **Model**: GPD Pocket 2 (7" variant)
- **Display**: 1920x1200 IPS (portrait-native, requires rotation)
- **CPU**: Intel Core m3-8100Y (Amber Lake, 2C/4T, 1.1-3.4GHz, 5W TDP)
- **GPU**: Intel UHD Graphics 615
- **RAM**: 8GB LPDDR3
- **Storage**: 128GB/256GB eMMC
- **Primary Use**: Portable workstation (development, SSH, terminal, notes)
- **Target IP**: nixos@192.168.1.218
- **Hostname**: TBD (Japanese mountain theme, pending approval)

---

## Kernel Selection Analysis

### Recommended Kernels for GPD Pocket 2 (Suspend/Hibernate)

| Kernel | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **6.6 LTS** | Most stable, fewest regressions, widely tested | Older, may lack newest power optimizations | **Safe choice** |
| **6.8.x** | Excellent suspend/hibernate (users report "1-2% battery loss overnight") | May have minor driver issues | **Best balance** |
| **6.12** | Latest features, newest i915 improvements | Some systemd 256+ interactions reported | Good for Intel |
| **Zen** | Better desktop responsiveness, preemptive scheduling | Less tested for suspend/hibernate | For gaming/responsiveness |

### Key Findings

1. **Kernel 6.8.x** has excellent reviews for suspend/hibernate on Intel mobile processors (Amber Lake like the m3-8100Y)
2. **LTS kernels** (6.6) are recommended by Arch Wiki when experiencing suspend/hibernate issues
3. **Linux 6.9+** supports changing hibernation compression algorithm (LZ4 faster than LZO)
4. Existing `oku` system uses **6.12** successfully for hibernate on Tiger Lake (similar to Amber Lake)

### GPD Pocket 2 Specific Issues

**MMC/SDHCI Suspend Blocker** (Pocket 2 MAX only):
- Phantom MMC host prevents suspend
- Fix: Blacklist `sdhci`, `sdhci_pci`, `mmc_core`
- **Note**: Standard Pocket 2 has microSD slot - may need this SD reader, so test before blacklisting

**Touchscreen After Hibernate**:
- Goodix touchscreen can act erratically after hibernation
- Fix: Reload goodix module on resume
```nix
powerManagement.resumeCommands = ''
  ${pkgs.kmod}/bin/modprobe -r goodix
  ${pkgs.kmod}/bin/modprobe goodix
'';
```

**USB-C Charging After Hibernate**:
- USB-C port may stop power negotiation after hibernate
- Fix: Reload fusb302 module (if applicable)

### Recommended Configuration

```nix
boot = {
  # Primary recommendation: 6.6 LTS for stability
  # Alternative: linuxPackages_6_8 for better power management
  kernelPackages = pkgs.linuxPackages_6_6;

  kernelParams = [
    "mem_sleep_default=deep"  # Prefer S3 deep sleep over s2idle
    "resume=/dev/disk/by-partlabel/disk-main-swap"  # Hibernation resume
  ];
};

# Suspend-then-hibernate: sleep for 30min, then hibernate
systemd.sleep.extraConfig = ''
  HibernateDelaySec=30m
'';

# Goodix touchscreen fix for hibernate
powerManagement.resumeCommands = ''
  ${pkgs.kmod}/bin/modprobe -r goodix
  ${pkgs.kmod}/bin/modprobe goodix
'';
```

---

## Phase 1: Remote Hardware Discovery (Agent Swarm)

### Agent 1: CPU & Thermal Profile
```bash
# Commands to execute on target
cat /proc/cpuinfo | grep -E "model name|cpu MHz|cache size"
lscpu
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp
```
**Purpose**: Verify CPU model, determine power management capabilities, identify thermal zones for fan control.

### Agent 2: Display & Graphics
```bash
# Display information
cat /sys/class/drm/card*/device/vendor
cat /sys/class/drm/card*/device/device
cat /sys/class/graphics/fb0/virtual_size
cat /sys/class/graphics/fb0/bits_per_pixel
# DRM/KMS info
ls -la /dev/dri/
cat /sys/class/drm/card0/edid | edid-decode 2>/dev/null || true
```
**Purpose**: Confirm i915 driver compatibility, get native resolution, verify KMS support.

### Agent 3: Input Devices (Touchscreen & Keyboard)
```bash
# Input device enumeration
cat /proc/bus/input/devices
# Touchscreen identification
ls -la /dev/input/event*
# Libinput info
libinput list-devices 2>/dev/null || true
# Check for Goodix touchscreen
dmesg | grep -i goodix
```
**Purpose**: Identify touchscreen driver (Goodix expected), verify keyboard/trackpoint detection.

### Agent 4: Storage & Boot
```bash
# Block devices
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
# EFI check
ls -la /sys/firmware/efi/
# Boot mode
cat /sys/firmware/efi/fw_platform_size 2>/dev/null || echo "Legacy BIOS"
# eMMC details
cat /sys/block/mmcblk*/device/name 2>/dev/null
```
**Purpose**: Determine disk layout for disko configuration, verify UEFI support.

### Agent 5: Network & Wireless
```bash
# Network interfaces
ip link show
# WiFi hardware
lspci | grep -i network
# Bluetooth
lsusb | grep -i bluetooth
# WiFi driver
dmesg | grep -iE "iwlwifi|brcm|broadcom"
# Firmware status
dmesg | grep -i firmware
```
**Purpose**: Identify WiFi chipset (likely Intel or Broadcom), check for firmware requirements.

### Agent 6: Power Management & Battery
```bash
# Battery info
cat /sys/class/power_supply/*/type
cat /sys/class/power_supply/BAT*/capacity 2>/dev/null
cat /sys/class/power_supply/BAT*/status 2>/dev/null
# Power management features
cat /sys/power/state
cat /sys/power/mem_sleep
# TLP or power-profiles-daemon status
systemctl status tlp 2>/dev/null || systemctl status power-profiles-daemon 2>/dev/null
```
**Purpose**: Verify battery detection, determine suspend/hibernate capabilities.

### Agent 7: Audio Hardware
```bash
# ALSA info
cat /proc/asound/cards
cat /proc/asound/card*/codec* 2>/dev/null | head -50
# PulseAudio/PipeWire
pactl info 2>/dev/null || pipewire --version 2>/dev/null
```
**Purpose**: Identify audio codec (RT5645 expected), configure PipeWire/ALSA.

### Agent 8: Sensors & Peripherals
```bash
# IIO sensors (accelerometer, gyro, ALS)
ls -la /sys/bus/iio/devices/
cat /sys/bus/iio/devices/*/name 2>/dev/null
# USB devices
lsusb
# I2C devices (for sensors)
ls /dev/i2c-* 2>/dev/null
```
**Purpose**: Check for accelerometer (auto-rotation), ambient light sensor.

---

## Phase 2: Configuration Research (Web Search Agents)

### Agent 9: GPD Pocket 2 Specific Issues
- Search for known Linux issues with GPD Pocket 2 m3-8100Y
- Kernel version compatibility
- Suspend/resume bugs
- Touchscreen calibration issues after sleep

### Agent 10: Display Rotation Best Practices
- Wayland/Hyprland rotation configuration
- Touch input transformation matrix
- Framebuffer rotation (early boot)

---

## Phase 3: Configuration Synthesis

Based on discovery results, create:

### 3.1 System Directory Structure
```
nix/systems/x86_64-linux/<hostname>/
├── default.nix      # Main system config
├── disko.nix        # Disk partitioning (eMMC-optimized)
├── home.nix         # Home-manager config
└── hardware.nix     # Hardware-specific overrides (optional)
```

### 3.2 Key Configuration Elements

#### Boot Configuration
```nix
boot = {
  kernelPackages = pkgs.linuxPackages_latest;  # Or _zen for better desktop response
  kernelParams = [
    "fbcon=rotate:1"                    # Portrait → Landscape rotation
    "i915.enable_fbc=1"                 # Frame buffer compression
    "i915.enable_psr=1"                 # Panel self-refresh (battery saving)
    "mem_sleep_default=deep"            # Better sleep mode
  ];
  initrd.kernelModules = [
    "i915"                              # Early KMS
    "pwm-lpss"                          # Brightness control
    "pwm-lpss-platform"
  ];
};
```

#### Display Rotation (Hyprland)
```nix
# In home.nix or hyprland config
monitor = "eDP-1, 1920x1200@60, 0x0, 1, transform, 1";  # 90° rotation
```

#### Touchscreen Calibration
```nix
# Wayland/libinput udev rule
services.udev.extraRules = ''
  ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="Goodix Capacitive TouchScreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
'';
```

#### Power Management
```nix
services.auto-cpufreq = {
  enable = true;
  settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };
};
```

#### Profile Selection
```nix
mountainous.profiles = {
  base.enable = true;
  laptop.enable = true;      # Hybrid-sleep, geoclue, touchpad
  workspace.enable = true;   # Hyprland, desktop portal, sound
};
```

---

## Phase 4: Hostname Selection

Proposed Japanese mountain names (following convention):
- **shirane** (白根山) - White peak, fitting for a small bright-screened device
- **tate** (立山) - Standing mountain, compact and upright
- **norikura** (乗鞍岳) - Saddle mountain, accessible

User to approve hostname before proceeding.

---

## Agent Execution Strategy

### Parallel Execution Groups

**Group A (Hardware Discovery)** - Run simultaneously:
- Agent 1: CPU & Thermal
- Agent 2: Display & Graphics
- Agent 3: Input Devices
- Agent 4: Storage & Boot
- Agent 5: Network & Wireless
- Agent 6: Power Management
- Agent 7: Audio Hardware
- Agent 8: Sensors & Peripherals

**Group B (Research)** - Run after Group A confirms hardware:
- Agent 9: GPD Pocket 2 Issues
- Agent 10: Display Rotation

**Group C (Synthesis)** - Sequential after all discovery:
- Generate default.nix based on collected data
- Generate disko.nix for eMMC layout
- Generate home.nix for workstation setup

---

## Expected Outputs

1. **Hardware Report**: JSON summary of all discovered hardware
2. **Configuration Files**:
   - `default.nix` - Full system configuration
   - `disko.nix` - Disk partitioning
   - `home.nix` - User environment
3. **Known Issues Document**: Any GPD Pocket 2 specific workarounds needed

---

## Sources & References

### GPD Pocket Hardware
- [GPD Pocket - NixOS Wiki](https://wiki.nixos.org/wiki/Hardware/GPD/GPD_Pocket)
- [GPD Pocket - ArchWiki](https://wiki.archlinux.org/title/GPD_Pocket)
- [GPD Pocket 2 Debian Installation](https://wiki.debian.org/InstallingDebianOn/GPD/Pocket2)
- [GPD Pocket 2 Ubuntu Scripts](https://github.com/joshskidmore/gpd-pocket2-ubuntu)
- [UMPC Ubuntu Scripts](https://github.com/wimpysworld/umpc-ubuntu)
- [Arch Linux Forums - GPD Pocket 2 Touchscreen Rotation](https://bbs.archlinux.org/viewtopic.php?id=258907)
- [GPD Pocket 2 Tips](https://www.ndhfilms.com/other/gpdpocket2)

### Suspend/Hibernate
- [Linux Kernel - System Sleep States](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
- [ArchWiki - Power Management/Suspend and Hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)
- [NixOS Wiki - Hibernation](https://nixos.wiki/wiki/Hibernation)
- [NixOS Wiki - Laptop](https://wiki.nixos.org/wiki/Laptop)
- [NixOS Wiki - Power Management](https://wiki.nixos.org/wiki/Power_Management)
- [GPD Community - Fix mmc1 Issues Preventing Suspend](https://gpd.digital/t/linux-fix-mmc1-issues-preventing-suspend/43)
- [Intel - Debug Suspend-Resume Issues](https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/debug-suspend-resume.html)

### GPD Pocket 2 Specifications
- [Amazon - GPD Pocket 2 Core m3-8100Y](https://www.amazon.com/update-cpu-m3-8100y-windows-graphics-bluetooth/dp/b07h2xgd6m)
- [Geekbuying - GPD Pocket 2](https://www.geekbuying.com/item/GPD-Pocket-2-Gamepad-Intel-Core-m3-8100y-8GB-128GB-Silver-411370.html)
