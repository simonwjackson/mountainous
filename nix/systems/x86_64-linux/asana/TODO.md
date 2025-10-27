# Samsung Galaxy Book3 Pro 360 - NixOS Implementation TODO

**System**: asana
**Hardware**: Samsung Galaxy Book3 Pro 360 (NP960QFG-KA1US)
**Goal**: Complete NixOS configuration with full hardware support

**Current Status**: Pre-deployment configuration phase - Priority 1 Complete ✅
**Last Updated**: 2025-10-27

---

## ⚡ Kernel & Power Management Decision

**Date**: 2025-10-27
**Status**: ✅ Configured

### Selected Configuration:
- **Kernel**: Linux 6.12 LTS (`pkgs.linuxPackages_6_12`)
- **Sleep Strategy**: Suspend-then-hibernate (30 minutes)
- **Power Management**: TLP (comprehensive device management)
- **Swap Size**: 20GB (for hibernate support)

### Rationale:

#### Why 6.12 LTS over other options?
1. **13th Gen Intel Optimization**: Hybrid CPU capacity scaling specifically for i7-1360P P+E core architecture
2. **Power Management Improvements**: Significant PM updates over 6.6, better than 6.9 regressions
3. **LTS Support**: Long-term backport support, NixOS 25.05 default
4. **Hardware Support**: Better SOF audio, Intel ISH sensors, WiFi 6E drivers
5. **Proven Stability**: Released May 2025, well-tested in production

**Alternative considered**: Linux 6.14 has "spectacular" ACPI suspend improvements (40-50% faster) but is less proven. Available if 6.12 sleep is insufficient.

#### Why Suspend-then-Hibernate?
**Problem**: S0ix (Modern Standby) on Linux drains 5-15% battery per hour on 13th Gen Intel laptops. True MacBook-like sleep with near-zero drain is not achievable with S0ix on Linux.

**Solution**: Hybrid approach provides best of both worlds:
- **0-30 minutes**: Normal suspend (fast 3-5 second wake) - acceptable drain for short breaks
- **After 30 minutes**: Automatic hibernate to disk (zero power drain) - prevents overnight battery death
- **Wake from hibernate**: 10-15 seconds (like cold boot) but preserves session

**User benefit**: Battery anxiety eliminated. Can close lid and forget about it.

#### Why TLP over auto-cpufreq?
- ✅ **Comprehensive**: Manages CPU, GPU, USB, PCIe, WiFi, Bluetooth, everything
- ✅ **Battery Care**: Charge threshold 40-80% extends battery lifespan
- ✅ **Mature**: Better integration with systemd suspend/hibernate
- ✅ **Proven**: More established for laptop power management
- ⚠️ **Conflict**: TLP and auto-cpufreq cannot coexist (both manage CPU frequency)

### Expected Battery Performance:
- **Active use (display 50%)**: 6-8 hours
- **Suspend (0-30 min)**: ~2-5% drain
- **Hibernate (30+ min)**: 0% drain (powered off)
- **Overnight closed lid**: 0% drain (hibernated)

### Known Limitations:
- S0ix will still drain some power during first 30 minutes
- Hibernate wake is slower than suspend wake
- If BIOS doesn't support S3, will use s2idle (higher drain)

### Fallback Options:
If battery drain is still unacceptable:
1. Try Linux 6.14 (newer ACPI improvements)
2. Reduce hibernate delay to 15 minutes
3. Check BIOS for S3 sleep option (may not exist)

---

# 🔧 PRE-DEPLOYMENT: Configuration Work

**These tasks can be completed NOW before deploying to hardware.**

## ✅ Critical Issue: Disk Configuration - RESOLVED

**Priority**: ~~MUST FIX BEFORE DEPLOYMENT~~ **COMPLETED**

Disk configuration has been fixed:
- [x] **Fixed device path**: Changed `/dev/sda` → `/dev/nvme0n1`
- [x] **Decision made**: Keeping LUKS2+Btrfs (preserve encryption)
  - Configuration: LUKS2 encrypted, Btrfs with subvolumes, impermanence configured
- [x] **Updated partition layout**: EFI (512M) + swap (20G) + LUKS2 (rest) with Btrfs
  - Subvolumes configured: @root (unused - tmpfs instead), @nix, @persist → /tundra/permafrost, @log
  - SSD optimizations: compress=zstd, noatime, discard=async
  - LUKS2 with Argon2id key derivation
- [x] **Impermanence**: tmpfs root (ephemeral), persistent storage at /tundra/permafrost, local config (zao pattern)

---

## ✅ Priority 1: Core System (Critical for Boot) - COMPLETED

### Boot & Firmware
- [x] Configure systemd-boot for UEFI
- [x] Enable EFI variable modification
- [x] Configure swap (20GB for hibernate support)
- [x] Set boot.resumeDevice for hibernate
- [x] Add Intel microcode updates (`hardware.cpu.intel.updateMicrocode = true`)
- [x] Configure initrd kernel modules (nvme, xhci_pci, thunderbolt, usb_storage, sd_mod)
- [x] Configure early KMS for i915 graphics
- [x] Add common kernel modules (i915, snd_sof_pci_intel_tgl, iwlmvm, btusb, hid_multitouch, intel_ishtp_hid)

### Storage & Filesystem
- [x] Configure filesystem mount options for SSD (noatime, nodiratime, discard=async, compress=zstd)
- [x] Enable fstrim service for SSD maintenance
- [x] LUKS2 configured with Argon2id key derivation
- [x] Btrfs subvolumes configured (@root, @nix, @persist → /tundra/permafrost, @log)
- [x] Impermanence configured (tmpfs root, local config following zao's pattern)
  - [x] tmpfs root filesystem (ephemeral, 2GB RAM)
  - [x] Persistent storage at /tundra/permafrost
  - [x] environment.persistence configuration
  - [x] systemd tmpfiles ownership fixes
  - [x] SSH host keys in persistent storage

---

## Priority 2: Graphics & Display

### Intel Graphics Driver
- [ ] Enable OpenGL/Vulkan support:
  ```nix
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;  # For 32-bit apps/games
    extraPackages = with pkgs; [
      intel-media-driver    # VAAPI (hardware video decode)
      intel-compute-runtime # OpenCL
      vpl-gpu-rt           # Intel VPL (Video Processing Library)
    ];
  };
  ```
- [x] Kernel parameters already set (i915.fastboot, enable_fbc, enable_psr)

### Display & HiDPI Configuration
- [ ] Add display resolution hint (optional):
  ```nix
  boot.kernelParams = [ "video=eDP-1:2880x1800@60" ];
  ```
- [ ] Configure HiDPI fonts:
  ```nix
  fonts = {
    fontconfig = {
      enable = true;
      antialias = true;
      hinting.enable = true;
    };
  };
  ```

---

## Priority 3: Input Devices

### Touchpad & Touchscreen
- [ ] Enable libinput with optimized settings:
  ```nix
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      disableWhileTyping = true;
      accelProfile = "adaptive";
      scrollMethod = "twofinger";
      clickMethod = "clickfinger";
    };
  };
  ```

### Stylus/Pen (Wacom)
- [ ] Enable Wacom support:
  ```nix
  services.xserver.wacom.enable = true;  # Works for both X11 and Wayland
  ```
- [ ] Add Wacom configuration packages:
  ```nix
  environment.systemPackages = with pkgs; [
    libwacom        # Wacom device support library
    xf86-input-wacom # Wacom driver
  ];
  ```

---

## Priority 4: Audio

### Audio Configuration (SOF - Sound Open Firmware)
- [ ] Enable sound:
  ```nix
  sound.enable = true;
  ```
- [ ] Enable PipeWire (modern audio server):
  ```nix
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;  # PulseAudio compatibility
    jack.enable = true;   # JACK compatibility (optional)
  };

  # Disable PulseAudio (conflicts with PipeWire)
  hardware.pulseaudio.enable = false;
  ```
- [ ] Add audio packages:
  ```nix
  environment.systemPackages = with pkgs; [
    pavucontrol  # GUI volume control
    alsa-utils   # alsamixer, aplay, etc.
  ];
  ```

---

## Priority 5: Network

### WiFi (Intel AX211 WiFi 6E)
- [ ] Enable NetworkManager:
  ```nix
  networking.networkmanager.enable = true;
  ```
- [x] User already in networkmanager group
- [ ] Configure WiFi power management:
  ```nix
  networking.networkmanager.wifi.powersave = true;
  ```

### Bluetooth
- [ ] Enable Bluetooth:
  ```nix
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;  # Enable experimental features
      };
    };
  };
  services.blueman.enable = true;  # Bluetooth manager GUI
  ```

---

## Priority 6: Power Management (Beyond TLP)

### Thermal Management
- [ ] Enable thermald:
  ```nix
  services.thermald.enable = true;
  ```

### Additional Power Tools
- [ ] Add power monitoring packages:
  ```nix
  environment.systemPackages = with pkgs; [
    powertop     # Already added
    tlp          # Already added
    acpi         # Battery/AC info
    lm_sensors   # Temperature monitoring
  ];
  ```

---

## Priority 7: 2-in-1 Features

### Sensor Support
- [ ] Enable IIO sensors:
  ```nix
  hardware.sensor.iio.enable = true;
  ```
- [ ] Install sensor proxy for rotation:
  ```nix
  hardware.sensor.iio.enable = true;
  services.udev.packages = [ pkgs.iio-sensor-proxy ];
  ```

### On-Screen Keyboard
- [ ] Add virtual keyboard for tablet mode:
  ```nix
  environment.systemPackages = with pkgs; [
    onboard  # On-screen keyboard
  ];
  ```

---

## Priority 8: USB & Thunderbolt

### Thunderbolt 4
- [ ] Enable Thunderbolt support:
  ```nix
  services.hardware.bolt.enable = true;  # Thunderbolt device authorization
  ```
- [ ] Add Thunderbolt management tool:
  ```nix
  environment.systemPackages = with pkgs; [
    thunderbolt  # boltctl for managing devices
  ];
  ```

---

## Priority 9: System Services

### ACPI Events
- [ ] Enable ACPI daemon:
  ```nix
  services.acpid.enable = true;
  ```

### Firmware Updates
- [ ] Enable fwupd for firmware updates:
  ```nix
  services.fwupd.enable = true;
  ```

---

## Priority 10: Additional Packages & Tools

### Hardware Monitoring Tools
- [ ] Add comprehensive monitoring tools:
  ```nix
  environment.systemPackages = with pkgs; [
    # Already added:
    # neovim, git, powertop, tlp

    # Add these:
    htop           # Process monitor
    btop           # Beautiful process monitor
    nvme-cli       # NVMe health monitoring
    smartmontools  # Drive health (smartctl)
    usbutils       # lsusb
    pciutils       # lspci
    dmidecode      # Hardware info
    inxi           # System information tool
    glxinfo        # OpenGL info
    vulkan-tools   # vulkaninfo
    wayland-utils  # wayland-info (if using Wayland)
  ];
  ```

---

## Priority 11: Desktop Environment (Optional)

**Decision needed**: Which desktop environment or window manager?

Options to consider for 2-in-1 devices:
- [ ] **GNOME** (excellent touch/tablet support, HiDPI-native)
  ```nix
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };
  ```
- [ ] **KDE Plasma** (highly customizable, good tablet mode)
  ```nix
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
  };
  ```
- [ ] **Hyprland** (if user prefers tiling, Wayland-native)
  ```nix
  programs.hyprland.enable = true;
  ```
- [ ] **None** (headless/minimal for now)

---

# 🧪 POST-DEPLOYMENT: Testing & Validation

**These tasks can ONLY be done AFTER deploying to hardware.**

## Phase 1: Boot & Basic Hardware (First Priority)

### Initial Boot
- [ ] System boots successfully from NVMe
- [ ] No critical errors in dmesg: `dmesg | grep -i error`
- [ ] No failed systemd services: `systemctl --failed`
- [ ] Verify kernel version: `uname -r` (should be 6.12.x)

### Storage Verification
- [ ] NVMe detected: `lsblk` shows nvme0n1
- [ ] Correct partitions mounted: `df -h`
- [ ] Swap active: `swapon --show` (should show 20GB)
- [ ] fstrim working: `sudo fstrim -v /`
- [ ] NVMe health check: `sudo nvme smart-log /dev/nvme0n1`
- [ ] Storage temperature: `cat /sys/class/hwmon/hwmon*/temp*_input`

### Firmware & Microcode
- [ ] Intel microcode loaded: `dmesg | grep microcode`
- [ ] Firmware files loaded: `dmesg | grep -i firmware`
- [ ] EFI variables accessible: `ls /sys/firmware/efi/efivars`

---

## Phase 2: Graphics & Display

### Graphics Driver
- [ ] i915 driver loaded: `lsmod | grep i915`
- [ ] DRM device present: `ls /dev/dri/`
- [ ] OpenGL working: `glxinfo | grep "direct rendering"`
- [ ] Vulkan working: `vulkaninfo --summary`
- [ ] Hardware acceleration: `vainfo` (should show Intel iHD driver)
- [ ] GPU firmware loaded: `dmesg | grep -i "guc\|huc\|dmc"`

### Display
- [ ] Built-in display detected: `cat /sys/class/drm/card*/status`
- [ ] Correct resolution: `xrandr` or `wayland-info`
- [ ] Brightness control works: `brightnessctl s 50%`
- [ ] Brightness keys functional
- [ ] HiDPI scaling looks correct
- [ ] No screen tearing during scrolling
- [ ] External display detection (test with USB-C)

---

## Phase 3: Input Devices

### Keyboard
- [ ] All keys responsive
- [ ] Function keys working (F1-F12, Fn combinations)
- [ ] Keyboard backlight functional
- [ ] Keyboard backlight keys work
- [ ] Correct keyboard layout

### Touchpad
- [ ] Touchpad detected: `libinput list-devices | grep -A5 Touchpad`
- [ ] Two-finger scroll works
- [ ] Tap to click works
- [ ] Multi-finger gestures work (3-finger swipe, pinch)
- [ ] Palm rejection effective
- [ ] Disable-while-typing works
- [ ] Pressure sensitivity appropriate

### Touchscreen
- [ ] Touchscreen detected: `libinput list-devices | grep -A5 Touch`
- [ ] 10-point multi-touch working
- [ ] Touch accuracy across entire screen
- [ ] Palm rejection for touch
- [ ] Edge swipes working
- [ ] Touch gestures in desktop environment

### Stylus/Pen
- [ ] Wacom stylus detected: `libinput list-devices | grep -A5 Wacom`
- [ ] Stylus reports position accurately
- [ ] Pressure sensitivity working (test in Krita/Inkscape)
- [ ] Hover detection working
- [ ] Stylus buttons mapped correctly
- [ ] Tilt detection (if supported)
- [ ] No lag or jitter

---

## Phase 4: Audio

### Audio Output
- [ ] Audio devices detected: `aplay -l`
- [ ] PipeWire running: `systemctl --user status pipewire`
- [ ] Built-in speakers work
- [ ] Speaker balance correct (L/R)
- [ ] Volume control works
- [ ] No distortion at high volume
- [ ] Headphone jack works
- [ ] Auto-switch to headphones when plugged
- [ ] HDMI audio (test with external display)

### Audio Input
- [ ] Microphone detected: `arecord -l`
- [ ] Microphone array works
- [ ] Microphone quality acceptable
- [ ] Noise cancellation effective
- [ ] Headset microphone works

---

## Phase 5: Network

### WiFi
- [ ] WiFi adapter detected: `ip link show` (should show wlo1 or similar)
- [ ] WiFi firmware loaded: `dmesg | grep iwlwifi`
- [ ] Can connect to 2.4 GHz network
- [ ] Can connect to 5 GHz network
- [ ] Can connect to 6 GHz network (WiFi 6E)
- [ ] WiFi stable (no disconnections)
- [ ] Speed test shows good performance
- [ ] WiFi survives suspend/resume
- [ ] No thermal throttling: `cat /sys/class/thermal/thermal_zone9/temp`

### Bluetooth
- [ ] Bluetooth controller detected: `bluetoothctl list`
- [ ] Can discover devices: `bluetoothctl scan on`
- [ ] Can pair devices (headphones, mouse, keyboard)
- [ ] Bluetooth audio works (A2DP)
- [ ] Bluetooth file transfer works
- [ ] Bluetooth survives suspend/resume

---

## Phase 6: Power Management (Critical Testing)

### Battery
- [ ] Battery detected: `cat /sys/class/power_supply/BAT1/status`
- [ ] Battery percentage accurate: `upower -i /org/freedesktop/UPower/devices/battery_BAT1`
- [ ] Charge threshold working: Check stops at ~80% when charging
- [ ] Charge threshold working: Check starts at ~40% when discharging
- [ ] Battery health shown: `cat /sys/class/power_supply/BAT1/capacity`
- [ ] Estimated time remaining reasonable

### CPU Power Management
- [ ] intel_pstate active: `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver`
- [ ] CPU frequency scales: Monitor `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`
- [ ] Governor on AC: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` (should be "performance")
- [ ] Governor on battery: Test after unplugging (should be "powersave")
- [ ] TLP active: `sudo tlp-stat -s`
- [ ] All CPU cores working: `lscpu` and `htop`

### Thermal Management
- [ ] thermald running: `systemctl status thermald`
- [ ] All thermal zones detected: `ls /sys/class/thermal/thermal_zone*/`
- [ ] CPU temperature reasonable idle: `cat /sys/class/thermal/thermal_zone*/temp` (<45°C)
- [ ] CPU temperature under load: Run stress test, monitor temps (<85°C)
- [ ] No thermal throttling under normal load
- [ ] Fan control working (listen for fan speed changes)
- [ ] NVMe temperature reasonable: `sudo nvme smart-log /dev/nvme0n1`

### Suspend & Hibernate (Most Critical)
- [ ] Suspend works: `systemctl suspend`
- [ ] Resume from suspend works (< 5 seconds)
- [ ] Suspend time acceptable (< 3 seconds to sleep)
- [ ] WiFi reconnects after resume
- [ ] Bluetooth reconnects after resume
- [ ] Touchpad works after resume
- [ ] Touchscreen works after resume
- [ ] Audio works after resume
- [ ] Graphics work after resume
- [ ] Check sleep state: `cat /sys/power/mem_sleep` (should show `[deep]` or `[s2idle]`)

- [ ] **Hibernate test**: Manually trigger hibernate: `systemctl hibernate`
- [ ] Resume from hibernate works (10-15 seconds is normal)
- [ ] Session preserved after hibernate
- [ ] All devices work after hibernate

- [ ] **Suspend-then-hibernate**: Leave suspended for 35+ minutes
- [ ] Verify automatic transition to hibernate
- [ ] Check journal: `journalctl -b | grep -i hibernate`
- [ ] Verify zero power drain during hibernate

- [ ] **Battery drain test**:
  - Note battery % before suspend
  - Suspend for 15 minutes
  - Check drain (should be < 2%)
  - Leave for 35+ minutes (should hibernate, 0% drain)

### Power Consumption
- [ ] Install and run powertop: `sudo powertop`
- [ ] Idle power consumption reasonable (< 5W)
- [ ] Display is biggest power consumer
- [ ] Runtime PM active for devices
- [ ] USB autosuspend working
- [ ] PCIe ASPM active

---

## Phase 7: 2-in-1 Features

### Sensors
- [ ] Sensor hub detected: `lsmod | grep intel_ishtp_hid`
- [ ] IIO sensors available: `ls /sys/bus/iio/devices/`
- [ ] Accelerometer working: `monitor-sensor` shows acceleration
- [ ] Gyroscope working: `monitor-sensor` shows rotation
- [ ] Ambient light sensor: `monitor-sensor` shows light level
- [ ] Hinge sensor present: `ls /sys/bus/iio/devices/ | grep hinge`

### Screen Rotation
- [ ] iio-sensor-proxy running: `systemctl status iio-sensor-proxy`
- [ ] Automatic rotation works in tablet mode
- [ ] Rotation lock toggle functional
- [ ] Rotation smooth and responsive
- [ ] Can manually lock orientation

### Mode Detection
- [ ] Laptop mode: Touchpad enabled, no rotation
- [ ] Tablet mode: Touchpad disabled (if configured), rotation enabled
- [ ] Tent mode: Detected correctly
- [ ] Stand mode: Detected correctly
- [ ] Virtual keyboard appears in tablet mode
- [ ] Transitions between modes smooth

### Ambient Light
- [ ] Auto-brightness enabled
- [ ] Brightness adjusts to lighting conditions
- [ ] Manual override works
- [ ] Brightness curves feel natural

---

## Phase 8: USB & Thunderbolt

### USB Ports
- [ ] All USB-A ports work (if any)
- [ ] Both USB-C ports work
- [ ] USB 3.2 speeds achieved: Test with fast USB drive
- [ ] USB devices survive suspend/resume

### Thunderbolt 4
- [ ] Thunderbolt module loaded: `lsmod | grep thunderbolt`
- [ ] bolt daemon running: `systemctl status bolt`
- [ ] Thunderbolt devices can be authorized: `boltctl list`
- [ ] Thunderbolt display works (if available)
- [ ] Thunderbolt daisy-chaining works (if available)

### USB-C Features
- [ ] USB-C display output (DP Alt Mode) works
- [ ] USB-C data + display simultaneously
- [ ] USB-C charging works
- [ ] Power Delivery negotiation: Check wattage accepted
- [ ] USB-C adapter recognized (already tested with Ethernet)

---

## Phase 9: Additional Hardware

### Webcam
- [ ] Webcam detected: `ls /dev/video*`
- [ ] Can capture video: `ffplay /dev/video0` or cheese
- [ ] Resolution and quality acceptable
- [ ] Works in video conferencing apps
- [ ] Privacy controls functional

### Fingerprint Reader (Optional)
- [ ] Reader detected: `lsusb | grep -i fingerprint`
- [ ] fprintd available (if supported)
- [ ] Can enroll fingerprints (if supported)
- [ ] PAM authentication works (if configured)

---

## Phase 10: Performance & Stress Testing

### CPU Performance
- [ ] Benchmark CPU: `sysbench cpu run`
- [ ] All 12 cores + 16 threads detected
- [ ] Turbo Boost working: Monitor frequencies under load
- [ ] P-cores and E-cores both utilized
- [ ] Single-thread performance good
- [ ] Multi-thread performance scales

### GPU Performance
- [ ] Benchmark GPU: `glmark2` or `unigine-heaven`
- [ ] Hardware acceleration in browser: Visit `chrome://gpu` or `about:support`
- [ ] Video decode acceleration: `mpv --hwdec=auto video.mp4` (low CPU usage)
- [ ] GPU frequency scaling: Monitor `/sys/class/drm/card0/gt_cur_freq_mhz`

### Storage Performance
- [ ] Benchmark NVMe: `sudo fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 --group_reporting --filename=/tmp/test`
- [ ] Read speeds > 3000 MB/s (PCIe 4.0 capable)
- [ ] Write speeds > 2000 MB/s
- [ ] NVMe power states active: `sudo nvme get-feature -f 0x0c -H /dev/nvme0n1`

### Memory
- [ ] Full 16GB detected: `free -h`
- [ ] Memory performance: `sysbench memory run`
- [ ] zram configured (if desired)

### Stress Testing
- [ ] CPU stress: `stress-ng --cpu 12 --timeout 300s` (5 minutes)
- [ ] Monitor temperatures during stress (should stay < 85°C)
- [ ] No kernel errors during stress
- [ ] System remains responsive
- [ ] Sustained load test: 30 minutes stress, verify no throttling

---

## Phase 11: Desktop Experience

### HiDPI
- [ ] System DPI/scaling configured correctly
- [ ] Text readable and sharp
- [ ] UI elements appropriately sized
- [ ] Applications respect scaling
- [ ] Font rendering excellent

### Multi-Monitor
- [ ] External monitor detected immediately
- [ ] Mirror mode works
- [ ] Extended desktop works
- [ ] Can arrange displays
- [ ] HiDPI + non-HiDPI mixed scaling (if needed)
- [ ] Monitor configs persist

### Gestures & Shortcuts
- [ ] Three-finger workspace swipe
- [ ] Four-finger gestures
- [ ] Pinch to zoom
- [ ] Stylus shortcuts
- [ ] Edge gestures
- [ ] Keyboard shortcuts

---

## Phase 12: Comprehensive Validation

### Boot Performance
- [ ] Measure boot time: `systemd-analyze`
- [ ] Boot time < 20 seconds (target)
- [ ] Identify slow services: `systemd-analyze blame`
- [ ] Optimize if needed

### System Health
- [ ] No errors in dmesg: `dmesg | grep -i error`
- [ ] No failed services: `systemctl --failed`
- [ ] Journal clean: `journalctl -p err -b`
- [ ] No ACPI errors: `dmesg | grep -i acpi.*error`

### Suspend/Resume Cycle Test
- [ ] Perform 10 consecutive suspend/resume cycles
- [ ] All cycles successful
- [ ] No increasing resume time
- [ ] No memory leaks
- [ ] All devices stable

### Real-World Battery Test
- [ ] Charge to 80% (verify threshold stops charging)
- [ ] Use normally for 2-3 hours
- [ ] Record battery drain rate (target: < 15% per hour light use)
- [ ] Estimate total battery life
- [ ] Test suspend-then-hibernate over lunch break
- [ ] Test overnight suspend (should hibernate)

---

## Phase 13: Known Issues Verification

### Expected Minor Issues
- [ ] WiFi thermal zone read errors (non-critical): `dmesg | grep thermal_zone9`
- [ ] i915 selective fetch warning (cosmetic): `dmesg | grep "Selective fetch"`
- [ ] ACPI DSM warning (cosmetic): `dmesg | grep DSM`
- [ ] All confirmed as non-functional impact

### Verify Workarounds Applied
- [ ] NVMe suspend quirk active: `dmesg | grep nvme | grep quirk`
- [ ] i915 parameters applied: `cat /proc/cmdline | grep i915`
- [ ] Deep sleep or s2idle active: `cat /sys/power/mem_sleep`

---

## Phase 14: Documentation

### System Documentation
- [ ] Document actual battery life achieved
- [ ] Document any additional kernel parameters needed
- [ ] Document any issues encountered and fixes
- [ ] Document BIOS settings used (if modified)
- [ ] Note any differences from HARDWARE.md scan

### Create Backup
- [ ] Create recovery USB with NixOS installer
- [ ] Test booting from recovery USB
- [ ] Document rollback procedure
- [ ] Export configuration to GitHub

---

## Completion Criteria

This system configuration is considered **COMPLETE** when:

1. ✅ All hardware components detected and functional
2. ✅ No critical errors in dmesg or journalctl
3. ✅ Battery life ≥ 6 hours light use (50% brightness)
4. ✅ Suspend/resume 100% reliable (10+ cycles tested)
5. ✅ Suspend-then-hibernate working (verified overnight)
6. ✅ All input devices working (keyboard, touchpad, touchscreen, stylus)
7. ✅ 2-in-1 mode detection and rotation working
8. ✅ Thermal management effective (no throttling normal use)
9. ✅ Display scaling provides readable, sharp text
10. ✅ Audio works on all outputs
11. ✅ Network connectivity stable (WiFi, Bluetooth)
12. ✅ System feels fast and responsive

---

## Quick Reference: Useful Commands

### Power Monitoring
```bash
# Battery status
upower -i /org/freedesktop/UPower/devices/battery_BAT1
cat /sys/class/power_supply/BAT1/capacity

# Power consumption
sudo powertop

# TLP status
sudo tlp-stat -s
sudo tlp-stat -b  # Battery info
```

### Hardware Info
```bash
# Graphics
glxinfo | grep "direct rendering"
vulkaninfo --summary
vainfo

# Sensors
monitor-sensor
cat /sys/bus/iio/devices/iio:device*/name

# Thermal
cat /sys/class/thermal/thermal_zone*/temp
sensors

# CPU
lscpu
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# NVMe
sudo nvme smart-log /dev/nvme0n1
```

### Sleep Testing
```bash
# Check sleep mode
cat /sys/power/mem_sleep

# Manual suspend
systemctl suspend

# Manual hibernate
systemctl hibernate

# Check suspend/hibernate in journal
journalctl -b | grep -i suspend
journalctl -b | grep -i hibernate
```

### System Health
```bash
# Boot time
systemd-analyze
systemd-analyze blame

# Errors
dmesg | grep -i error
journalctl -p err -b
systemctl --failed
```

---

**Last Updated**: 2025-10-27
**Status**: Priority 1 Complete - Ready for Priority 2 (Graphics & Display)
**Next Step**: Configure OpenGL/Vulkan support, HiDPI scaling, and backlight control
