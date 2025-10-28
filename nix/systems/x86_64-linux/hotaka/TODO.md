# AYANEO AIR - NixOS Implementation TODO

**System**: hotaka
**Hardware**: AYANEO AIR Handheld Gaming PC
**Goal**: Complete NixOS gaming handheld configuration with full hardware support
**Deployment Method**: nixos-anywhere (remote deployment)

**Current Status**: Pre-deployment configuration phase
**Last Updated**: 2025-10-27

---

## ⚡ Power Management & Gaming Performance Strategy

**Date**: 2025-10-27
**Status**: 🔄 To Be Configured

### Handheld Gaming Considerations:

#### Key Challenges:

1. **Small Battery**: 28.3 Wh (vs typical laptop 50-70 Wh)
2. **High Performance Demand**: Gaming workloads drain faster
3. **Thermal Constraints**: Compact handheld form factor
4. **TDP Balancing**: Performance vs battery life tradeoff

#### Recommended Configuration:

- **Kernel**: Linux 6.12 LTS (best AMD Zen 3 support, stable gaming)
  - Alternative: 6.14 for newer AMD improvements
- **CPU Governor**:
  - **AC Power**: schedutil (balanced performance/efficiency)
  - **Battery**: powersave with configurable TDP limits
- **Power Management**: auto-cpufreq or TLP
  - **auto-cpufreq**: Better for dynamic gaming workloads
  - **TLP**: More granular control for handheld optimization
- **Sleep Strategy**: Deep sleep or s2idle (handheld-optimized)
- **Swap**: 16GB (already configured, hibernate support)

#### TDP Management Strategy:

The Ryzen 5 5560U supports configurable TDP (10W-25W):

- **Performance Mode** (AC): 25W TDP - Maximum gaming performance
- **Balanced Mode**: 15W TDP - Good performance, moderate battery
- **Battery Saver**: 10W TDP - Extended battery, light gaming/browsing

Tools to consider:

- RyzenAdj (if available in nixpkgs)
- Custom systemd services for TDP profiles
- Gamemode integration for automatic performance switching

#### Expected Battery Performance:

- **Gaming (15W TDP)**: 1-2 hours
- **Gaming (10W TDP)**: 2-3 hours
- **Web browsing**: 3-4 hours
- **Video playback**: 4-5 hours
- **Idle/sleep**: Minimal drain with proper configuration

#### Gaming-Specific Features to Enable:

- Gamemode (automatic performance boost when gaming)
- MangoHud (FPS/performance overlay)
- Steam with Proton GE
- GameScope compositor (Steam Deck UI-like experience)
- Controller support (built-in gamepad + external controllers)

---

# 🔧 PRE-DEPLOYMENT: Configuration Work

**These tasks can be completed NOW before deploying to hardware via nixos-anywhere.**

## ✅ Critical: Verify Disk Configuration

**Priority**: **MUST VERIFY BEFORE DEPLOYMENT**

Current configuration check:

- [x] **Device path correct**: `/dev/nvme0n1` (512GB NVMe SSD)
- [x] **Boot**: 512M EFI partition (FAT32)
- [x] **Swap**: 16GB (for hibernate support)
- [x] **Root**: Direct XFS filesystem - **NO ENCRYPTION**
- [x] **Filesystem**: XFS with gaming optimizations (noatime, discard, largeio)
- [x] **Impermanence**: tmpfs root (2GB), persistent storage at /tundra/permafrost

**Note**: Review `nix/systems/x86_64-linux/hotaka/disko.nix` before deployment!

---

## Priority 1: Core System (Critical for Boot)

### Boot & Firmware

- [x] Configure systemd-boot for UEFI
- [x] Enable EFI variable modification
- [x] Configure swap (16GB, already present)
- [x] Set boot.resumeDevice for hibernate
- [x] Add AMD microcode updates (`hardware.cpu.amd.updateMicrocode = true`)
- [x] Configure initrd kernel modules (nvme, xhci_pci, usb_storage, sd_mod)
- [x] Configure early KMS for amdgpu graphics
- [x] Add common kernel modules (amdgpu, kvm-amd, mt7921e, btusb, hid_multitouch)

### AMD-Specific Kernel Parameters

- [x] Set `amdgpu.ppfeaturemask=0xffffffff` (enable all GPU power features)
- [x] Set `amdgpu.gpu_recovery=1` (enable GPU hang recovery)
- [x] Set `amd_pstate=active` (use active P-state driver)
- [x] Consider `amdgpu.dc=1` (Display Core for better display support)
- [x] Consider `amdgpu.dpm=1` (Dynamic Power Management)

### Storage & Filesystem

- [x] Configure XFS mount options for SSD (noatime, nodiratime, discard, logbufs=8, largeio)
- [x] Enable fstrim service for SSD maintenance (async TRIM via mount option)
- [x] Verify XFS filesystem configured with gaming optimizations
- [x] Review impermanence setup:
  - [x] tmpfs root (2GB, ephemeral)
  - [x] /tundra/permafrost (persistent: /nix, /home, /var/lib)
  - [x] Gaming saves persist in /home/simonwjackson/.local/share/

---

## Priority 2: Graphics & Display (Critical for Gaming)

### AMD Radeon Graphics (Cezanne)

- [x] Enable OpenGL/Vulkan support (`hardware.graphics.enable = true`)
- [x] Enable 32-bit graphics support (`hardware.graphics.enable32Bit = true`)
- [x] Add AMD graphics packages:
  - [x] amdvlk (AMD Vulkan driver)
  - [x] amdvlk-32bit (for 32-bit games)
  - [x] mesa drivers
  - [x] rocm-opencl-icd (OpenCL support)
- [x] Enable AMD GPU OpenCL (`hardware.amdgpu.opencl.enable = true`)
- [x] Configure VAAPI for hardware video decode

### Display Configuration (7" 1080p, 314 PPI)

- [x] Set display resolution hint: `video=eDP-1:1920x1080@60`
- [x] Configure HiDPI scaling (150-200% scale recommended)
- [x] Install brightnessctl for backlight control
- [ ] Configure fonts for high DPI:
  - [ ] Font antialiasing
  - [ ] Subpixel hinting
  - [ ] Font sizes appropriate for handheld

### Gaming-Specific Graphics

- [x] Install MangoHud for FPS overlay
- [ ] Install vkBasalt for graphics post-processing (optional)
- [x] Install gamemode for performance optimization
- [x] Configure gamescope compositor (optional, Steam Deck-like)

---

## Priority 3: Input Devices (Gaming Critical)

### Touchscreen

- [ ] Enable libinput
- [ ] Configure touchscreen settings:
  - [ ] Tap to click
  - [ ] Multi-touch gestures
  - [ ] Palm rejection
- [ ] No "disable while typing" (handheld device)

### Built-in Gamepad Controls

**CRITICAL**: The built-in gamepad controls must work!

- [ ] Verify xpad module loaded (for Xbox 360-style controllers)
- [ ] Test if built-in controls detected as gamepad
- [ ] May need custom udev rules or kernel parameters
- [ ] Consider xboxdrv if xpad doesn't work
- [ ] Test analog stick deadzones and calibration
- [ ] Verify all buttons mapped correctly:
  - [ ] Left/Right analog sticks
  - [ ] D-pad
  - [ ] ABXY buttons
  - [ ] L1/R1 shoulder buttons
  - [ ] L2/R2 triggers
  - [ ] Select/Start/Menu buttons
  - [ ] Special buttons (turbo, etc.)

### External Controllers

- [ ] Enable xpadneo for external Xbox controllers via Bluetooth
- [ ] Enable PlayStation controller support (ds4drv or built-in)
- [ ] Enable Nintendo controller support (joycond)

### Keyboard Support

- [ ] Hardware keyboard detected
- [ ] On-screen keyboard for handheld mode (onboard)
- [ ] Keyboard shortcuts for gaming overlay

---

## Priority 4: Audio (Gaming Quality)

### Audio Configuration

- [x] Enable sound subsystem (`sound.enable = true`)
- [x] Enable PipeWire with low latency:
  - [x] ALSA support (including 32-bit for games)
  - [x] PulseAudio compatibility
  - [x] JACK compatibility
- [x] Configure low-latency audio for gaming:
  ```nix
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-gaming.conf" ''
      monitor.alsa.rules = [
        {
          matches = [ { node.name = "~alsa_output.*" } ]
          actions = {
            update-props = {
              api.alsa.period-size = 256
              api.alsa.headroom = 1024
            }
          }
        }
      ]
    '')
  ];
  ```
- [x] Add audio packages:
  - [x] pavucontrol (GUI volume control)
  - [x] alsa-utils (CLI tools)
  - [x] pulseaudio (for compatibility)

### Audio Hardware

- [x] Built-in speakers configuration
- [x] Headphone jack detection
- [x] HDMI/DisplayPort audio (for external displays)
- [x] Microphone support

---

## Priority 5: Network

### WiFi (MediaTek MT7921 WiFi 6E)

- [ ] Enable NetworkManager
- [ ] Add user to networkmanager group
- [ ] Configure WiFi power management:
  - [ ] `wifi.powersave = false` (gaming prioritizes performance)
  - [ ] Or configurable per-profile
- [ ] Ensure mt7921e driver available
- [ ] WiFi firmware included in linux-firmware

### Bluetooth

- [ ] Enable Bluetooth hardware support
- [ ] Power on boot enabled
- [ ] Configure bluez with all audio profiles
- [ ] Enable experimental features (better codec support for headphones)
- [ ] Enable blueman GUI for device management
- [ ] Low-latency Bluetooth audio configuration

### Network Optimization for Gaming

- [ ] Consider disabling WiFi power saving for competitive gaming
- [ ] Configure DNS for low latency (1.1.1.1 or 8.8.8.8)
- [ ] Enable BBR congestion control (optional)

---

## Priority 6: Power Management (Handheld-Specific)

### CPU Power Management

Choose ONE of the following:

#### Option A: auto-cpufreq (Recommended for gaming handheld)

- [ ] Enable auto-cpufreq
- [ ] Configure profiles:
  ```nix
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    charger = {
      governor = "schedutil";
      turbo = "auto";
      scaling_min_freq = 400000;
      scaling_max_freq = 4062000;
    };
    battery = {
      governor = "powersave";
      turbo = "auto";  # Allow turbo for responsive gaming on battery
      scaling_min_freq = 400000;
      scaling_max_freq = 2800000;  # Cap for battery life
      energy_performance_preference = "balance_power";
    };
  };
  ```

#### Option B: TLP (More granular control)

- [ ] Enable TLP
- [ ] Configure TLP settings for handheld:

  ```nix
  services.tlp.enable = true;
  services.tlp.settings = {
    # CPU
    CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 1;  # Keep for gaming responsiveness
    CPU_MIN_PERF_ON_AC = 0;
    CPU_MAX_PERF_ON_AC = 100;
    CPU_MIN_PERF_ON_BAT = 0;
    CPU_MAX_PERF_ON_BAT = 70;  # Cap for battery life

    # AMD GPU
    RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
    RADEON_DPM_PERF_LEVEL_ON_BAT = "low";

    # Don't suspend USB (controllers need to stay active)
    USB_AUTOSUSPEND = 0;

    # Aggressive disk power management
    SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
  };
  ```

### Battery Care

- [ ] Configure charge thresholds (if supported by AYANEO firmware)
- [ ] Add battery monitoring packages (acpi, powertop)

### Thermal Management

- [ ] No thermald needed (not Intel)
- [ ] Verify amdgpu thermal management active
- [ ] Monitor CPU/GPU thermals (important for handheld)

### TDP Management (Advanced)

- [ ] Research RyzenAdj availability in nixpkgs
- [ ] Create TDP profile switching service (optional)
- [ ] Integrate with gamemode for auto-performance boost

---

## Priority 7: Gaming Software Stack

### Essential Gaming Packages

- [ ] **Steam**: Primary gaming platform
  ```nix
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;  # Steam Deck-like experience
  };
  ```
- [ ] **Proton GE**: Better game compatibility
- [ ] **Gamemode**: Automatic performance optimization
- [ ] **MangoHud**: Performance overlay (FPS, temps, etc.)
- [ ] **Gamescope**: Compositor for gaming (optional)
- [ ] **Lutris**: For non-Steam games
- [ ] **Heroic**: Epic Games launcher

### Game Controllers

- [ ] **xpadneo**: Xbox controller support (Bluetooth)
- [ ] **ds4drv** or kernel support: PlayStation controllers
- [ ] **joycond**: Nintendo Switch controllers
- [ ] **antimicrox**: Controller-to-keyboard mapping

### Emulators (Optional)

- [ ] RetroArch (multi-system emulator)
- [ ] PCSX2 (PS2)
- [ ] RPCS3 (PS3)
- [ ] Dolphin (GameCube/Wii)
- [ ] Yuzu (Switch)
- [ ] PPSSPP (PSP)

### Gaming Utilities

- [ ] **protontricks**: Winetricks for Proton games
- [ ] **steamtinkerlaunch**: Advanced Steam game customization
- [ ] **mangohud**: FPS counter and performance monitoring
- [ ] **goverlay**: MangoHud GUI configuration
- [ ] **vkBasalt**: Post-processing effects

---

## Priority 8: Desktop Environment / Gaming Interface

**Decision needed**: Choose gaming-optimized interface

### Option A: Gamescope + Steam (Steam Deck-like)

Recommended for dedicated gaming handheld experience:

- [ ] Enable gamescope session
- [ ] Configure Steam Big Picture as default
- [ ] Auto-launch Steam on boot
- [ ] Configure virtual keyboard in Steam
- [ ] Handheld-friendly interface

### Option B: KDE Plasma (Balanced)

Good for gaming + general computing:

- [ ] Enable KDE Plasma
- [ ] Configure for handheld (large touch targets)
- [ ] Steam integration
- [ ] Can switch between desktop and gaming mode

### Option C: GNOME (Touch-friendly)

Best for general computing with touch:

- [ ] Enable GNOME
- [ ] Configure for high DPI
- [ ] Add gaming extensions
- [ ] Touch-optimized

### Option D: Hyprland + Gamemode (Tiling WM)

For advanced users:

- [ ] Enable Hyprland
- [ ] Configure gaming-specific workspaces
- [ ] Gamemode integration
- [ ] Requires more configuration

---

## Priority 9: Display & Scaling

### HiDPI Configuration (314 PPI)

- [ ] Set system-wide scaling (150-200%)
- [ ] Configure Xresources DPI: `Xft.dpi: 314`
- [ ] Or GDK/QT scaling:
  ```nix
  environment.variables = {
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.5";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  };
  ```
- [ ] Test applications for proper scaling
- [ ] Configure terminal font sizes
- [ ] Adjust Steam Big Picture scaling

### Display Rotation (Optional)

- [ ] Portrait mode support (native 1080x1920)
- [ ] Or landscape with rotation (1920x1080)
- [ ] Auto-rotation if sensors available

---

## Priority 10: Additional System Services

### ACPI Events

- [ ] Enable ACPI daemon (`services.acpid.enable = true`)
- [ ] Power button behavior (suspend/shutdown menu)
- [ ] Lid switch behavior (if applicable)

### Firmware Updates

- [ ] Enable fwupd (`services.fwupd.enable = true`)
- [ ] May support BIOS updates for AYANEO

### System Monitoring

- [ ] Add hardware monitoring tools:
  - [ ] htop, btop (process monitors)
  - [ ] nvme-cli, smartmontools (drive health)
  - [ ] lm_sensors (temperature)
  - [ ] ryzen_smu (Ryzen monitoring, if available)

### Game Save Management

- [ ] Ensure Steam cloud sync enabled
- [ ] Consider syncthing for non-Steam saves
- [ ] Backup important game saves to persistent storage
- [ ] If using impermanence, whitelist game save directories

---

## Priority 11: Networking & Online Gaming

### Network Optimizations

- [ ] Disable WiFi power saving for online gaming
- [ ] Configure network buffer sizes (optional):
  ```nix
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 67108864";
    "net.ipv4.tcp_wmem" = "4096 65536 67108864";
  };
  ```
- [ ] Consider BBR congestion control for better latency

### Firewall

- [ ] Allow Steam remote play
- [ ] Allow game-specific ports (if needed)
- [ ] Consider UPnP for automatic port forwarding

---

## Priority 12: Suspend/Hibernate Configuration

### Sleep Strategy

- [ ] Configure suspend-then-hibernate:
  ```nix
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30min
  '';
  services.logind.lidSwitchExternalPower = "suspend";
  ```
- [ ] Or simple suspend (faster wake for quick gaming sessions)
- [ ] Test suspend/resume with running games

### Hibernate Support

- [ ] Verify swap size (16GB should be sufficient for 13GB RAM)
- [ ] Set boot.resumeDevice to swap partition
- [ ] Test hibernate/resume

---

---

# 🧪 POST-DEPLOYMENT: Testing & Validation

**These tasks can ONLY be done AFTER deploying to hardware via nixos-anywhere.**

## Phase 1: Boot & Basic Hardware (First Priority)

### Initial Boot

- [ ] System boots successfully from NVMe
- [ ] No critical errors in dmesg: `dmesg | grep -i error`
- [ ] No failed systemd services: `systemctl --failed`
- [ ] Verify kernel version: `uname -r` (should be 6.12.x or chosen version)

### Storage Verification

- [ ] NVMe detected: `lsblk` shows nvme0n1
- [ ] Correct partitions mounted: `df -h`
- [ ] Swap active: `swapon --show` (should show 16GB)
- [ ] fstrim working: `sudo fstrim -v /`
- [ ] NVMe health check: `sudo nvme smart-log /dev/nvme0n1`
- [ ] Storage temperature: `cat /sys/class/hwmon/hwmon*/temp*_input`

### Firmware & Microcode

- [ ] AMD microcode loaded: `dmesg | grep microcode`
- [ ] Firmware files loaded: `dmesg | grep -i firmware`
- [ ] EFI variables accessible: `ls /sys/firmware/efi/efivars`

---

## Phase 2: Graphics & Display (Gaming Critical)

### AMD Graphics Driver

- [ ] amdgpu driver loaded: `lsmod | grep amdgpu`
- [ ] DRM device present: `ls /dev/dri/`
- [ ] OpenGL working: `glxinfo | grep "direct rendering"`
- [ ] Vulkan working: `vulkaninfo --summary`
- [ ] Hardware acceleration: `vainfo` (should show AMD drivers)
- [ ] GPU firmware loaded: `dmesg | grep -i amdgpu`
- [ ] Check GPU info: `lspci -k | grep -A3 VGA`

### Display

- [ ] Built-in display detected and working
- [ ] Correct resolution: 1920x1080 (or 1080x1920 portrait)
- [ ] Brightness control works: `brightnessctl s 50%`
- [ ] Brightness keys functional
- [ ] HiDPI scaling appropriate for 7" screen
- [ ] Text readable at arm's length (handheld distance)
- [ ] No screen tearing in games
- [ ] Check display info: `cat /sys/class/drm/card*/card*/modes`

### Graphics Performance

- [ ] Benchmark GPU: `glmark2`
- [ ] Check Vulkan: `vkcube` or `vulkan-smoketest`
- [ ] Test 3D performance: Run a simple game
- [ ] GPU frequency scaling: `cat /sys/class/drm/card0/device/pp_dpm_sclk`
- [ ] GPU power state: `cat /sys/class/drm/card0/device/power_dpm_state`

---

## Phase 3: Input Devices (Gaming Critical)

### Touchscreen

- [ ] Touchscreen detected: `libinput list-devices | grep -A10 Touch`
- [ ] Multi-touch working (test with pinch gesture)
- [ ] Touch accuracy across entire screen
- [ ] Touch responsiveness acceptable for gaming menus
- [ ] No ghost touches
- [ ] Touch works after suspend/resume

### Built-in Gamepad Controls (CRITICAL)

**Most important test for gaming handheld!**

- [ ] Gamepad detected: `ls /dev/input/js*` or `evtest`
- [ ] List input devices: `cat /proc/bus/input/devices`
- [ ] Test with jstest: `jstest /dev/input/js0`

#### Individual Control Tests:

- [ ] **Left Analog Stick**: Full range of motion, no drift
- [ ] **Right Analog Stick**: Full range of motion, no drift
- [ ] **D-Pad**: All 8 directions register
- [ ] **A Button**: Registers
- [ ] **B Button**: Registers
- [ ] **X Button**: Registers
- [ ] **Y Button**: Registers
- [ ] **L1 (Left Bumper)**: Registers
- [ ] **R1 (Right Bumper)**: Registers
- [ ] **L2 (Left Trigger)**: Full analog range
- [ ] **R2 (Right Trigger)**: Full analog range
- [ ] **Select/Back Button**: Registers
- [ ] **Start/Menu Button**: Registers
- [ ] **Home/Guide Button**: Registers (if present)
- [ ] **L3 (Left Stick Click)**: Registers
- [ ] **R3 (Right Stick Click)**: Registers
- [ ] **Special Buttons**: Test any turbo/macro buttons

#### Advanced Controller Tests:

- [ ] Dead zones appropriate (not too large, not too sensitive)
- [ ] No input lag
- [ ] Buttons don't stick or double-register
- [ ] Controllers survive suspend/resume
- [ ] Test in actual game (best real-world test)

### External Controllers

- [ ] External USB controller detected
- [ ] External Bluetooth controller pairs and works
- [ ] Multiple controllers work simultaneously (if needed)

### Keyboard

- [ ] Hardware keyboard working (all keys)
- [ ] On-screen keyboard appears when needed
- [ ] Can type in games/Steam

---

## Phase 4: Audio (Gaming Quality)

### Audio Output

- [ ] Audio devices detected: `aplay -l`
- [ ] PipeWire running: `systemctl --user status pipewire`
- [ ] Built-in speakers work
- [ ] Speaker volume adequate
- [ ] No crackling or distortion
- [ ] Audio latency acceptable for gaming
- [ ] Headphone jack works
- [ ] Auto-switch to headphones when plugged
- [ ] HDMI audio works (if using external display)
- [ ] Volume keys functional

### Audio Quality

- [ ] Test game audio
- [ ] Test music playback
- [ ] Test voice chat (Discord, Steam voice)
- [ ] No audio stuttering during gameplay
- [ ] Audio survives suspend/resume

### Audio Input

- [ ] Microphone detected: `arecord -l`
- [ ] Microphone works in voice chat
- [ ] Microphone quality acceptable
- [ ] Headset microphone works

---

## Phase 5: Network

### WiFi (Critical for online gaming)

- [ ] WiFi adapter detected: `ip link show wlp2s0`
- [ ] WiFi firmware loaded: `dmesg | grep mt7921`
- [ ] Can connect to 2.4 GHz network
- [ ] Can connect to 5 GHz network
- [ ] Can connect to 6 GHz network (WiFi 6E)
- [ ] WiFi stable during gaming (no drops)
- [ ] Latency acceptable: `ping 8.8.8.8`
- [ ] Download speed test
- [ ] Upload speed test
- [ ] WiFi survives suspend/resume
- [ ] Test online game (best real-world test)

### Bluetooth

- [ ] Bluetooth controller detected: `bluetoothctl list`
- [ ] Can pair Bluetooth headphones
- [ ] Can pair Bluetooth controllers
- [ ] Bluetooth audio quality good (check codec: `pactl list | grep a2dp`)
- [ ] Bluetooth audio latency acceptable for gaming
- [ ] Bluetooth survives suspend/resume

---

## Phase 6: Power Management (Handheld Critical)

### Battery

- [ ] Battery detected: `cat /sys/class/power_supply/BAT0/status`
- [ ] Battery percentage shown: `upower -i /org/freedesktop/UPower/devices/battery_BAT0`
- [ ] Battery percentage accurate
- [ ] Charge/discharge rate reasonable
- [ ] Can charge via USB-C
- [ ] Charging indicator works
- [ ] Battery doesn't drain while plugged in during gaming

### CPU Power Management

- [ ] amd_pstate active: `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver`
- [ ] CPU frequency scales: Monitor with `watch -n1 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"`
- [ ] Governor on AC: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
- [ ] Governor on battery: Test after unplugging
- [ ] auto-cpufreq or TLP active: `systemctl status auto-cpufreq` or `sudo tlp-stat -s`
- [ ] All 6 cores + 12 threads working: `lscpu` and `htop`

### GPU Power Management

- [ ] GPU power management active: `cat /sys/class/drm/card0/device/power_dpm_state`
- [ ] GPU frequency scales: `cat /sys/class/drm/card0/device/pp_dpm_sclk`
- [ ] GPU clocks down when idle
- [ ] GPU clocks up during gaming

### Thermal Management (Critical for Handheld)

- [ ] CPU temperature at idle: `cat /sys/class/hwmon/hwmon2/temp1_input` (should be <45°C)
- [ ] GPU temperature at idle
- [ ] CPU temperature while gaming: Run game, monitor temps (should stay <85°C)
- [ ] GPU temperature while gaming (should stay <85°C)
- [ ] No thermal throttling during normal gaming
- [ ] Fan audible but not excessively loud
- [ ] Case doesn't get uncomfortably hot
- [ ] Check all thermal zones: `ls /sys/class/thermal/thermal_zone*/`

### Suspend & Resume

- [ ] Suspend works: `systemctl suspend`
- [ ] Resume from suspend works (<5 seconds)
- [ ] WiFi reconnects after resume
- [ ] Bluetooth reconnects after resume
- [ ] Audio works after resume
- [ ] Graphics work after resume
- [ ] Controllers work after resume
- [ ] Games can be resumed (or restart gracefully)
- [ ] Check sleep state: `cat /sys/power/mem_sleep`

### Hibernate (If Configured)

- [ ] Hibernate works: `systemctl hibernate`
- [ ] Resume from hibernate works (10-15 seconds)
- [ ] Session preserved after hibernate
- [ ] All devices work after hibernate

### Battery Life Testing (Real-World)

- [ ] **Gaming test**: Play demanding game, measure drain rate
  - Target: 1-2 hours at 15W TDP
- [ ] **Light gaming test**: Play 2D/indie game, measure drain
  - Target: 2-3 hours
- [ ] **Video playback test**: Stream video, measure drain
  - Target: 4-5 hours
- [ ] **Web browsing test**: General use, measure drain
  - Target: 3-4 hours
- [ ] **Suspend drain test**: Suspend for 30 minutes, check % loss
  - Target: <5%

---

## Phase 7: Gaming Performance (Most Important!)

### Steam

- [ ] Steam installed and launches
- [ ] Can log in to Steam
- [ ] Steam downloads games
- [ ] Steam recognizes controllers
- [ ] Steam Big Picture mode works
- [ ] Steam Big Picture optimized for handheld

### Native Linux Games

- [ ] Test a native Linux game (e.g., CS:GO, Dota 2)
- [ ] Game runs smoothly
- [ ] FPS acceptable for game type
- [ ] Controls work in game
- [ ] Audio works in game
- [ ] No crashes or freezes
- [ ] Can exit game properly

### Proton Games (Windows Games)

- [ ] Proton/Wine installed
- [ ] Download a Proton game
- [ ] Proton GE available (if configured)
- [ ] Game launches via Proton
- [ ] Game runs at playable FPS
- [ ] Controls work
- [ ] Audio works
- [ ] Saves work
- [ ] Test multiple Proton games (compatibility)

### Gaming Performance Metrics

- [ ] Install MangoHud
- [ ] Enable MangoHud overlay: `mangohud %command%` in Steam launch options
- [ ] Monitor FPS during gaming
- [ ] Monitor GPU usage
- [ ] Monitor CPU usage
- [ ] Monitor temperatures
- [ ] Monitor VRAM usage
- [ ] Target: 60 FPS on medium settings for modern games, 30+ FPS for AAA

### Gamemode

- [ ] Gamemode installed
- [ ] Gamemode activates when game launches: `gamemoded -s`
- [ ] Performance improvement noticeable
- [ ] CPU governor switches to performance
- [ ] Check gamemode status: `gamemoded -t`

### TDP Management During Gaming

- [ ] Monitor power draw during gaming
- [ ] Test different TDP settings (if configured)
  - [ ] 10W TDP: Playable FPS, extended battery
  - [ ] 15W TDP: Good performance, moderate battery
  - [ ] 25W TDP: Maximum performance, short battery
- [ ] Verify TDP switching works (if configured)

### Emulation (If Configured)

- [ ] RetroArch launches
- [ ] Test PS2 emulation (PCSX2)
- [ ] Test GameCube emulation (Dolphin)
- [ ] Emulators recognize controllers
- [ ] Emulation performance acceptable

---

## Phase 8: Display & Scaling

### HiDPI Verification

- [ ] System-wide scaling configured
- [ ] Text readable at handheld distance (~30cm)
- [ ] UI elements appropriately sized
- [ ] Steam interface scaled correctly
- [ ] Games respect scaling (or run at native res)
- [ ] Font rendering sharp and clear

### External Display (Optional)

- [ ] External monitor detected via USB-C
- [ ] Can mirror display
- [ ] Can extend display
- [ ] HDMI audio works on external display
- [ ] External display at full resolution
- [ ] Can game on external display

---

## Phase 9: Stress Testing

### CPU Stress Test

- [ ] Run CPU stress: `stress-ng --cpu 12 --timeout 300s`
- [ ] Monitor temperatures: Should stay <85°C
- [ ] Monitor throttling: `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`
- [ ] System remains responsive
- [ ] No crashes or kernel errors
- [ ] Fans ramp up appropriately

### GPU Stress Test

- [ ] Run GPU benchmark: `glmark2` or `unigine-heaven`
- [ ] Monitor GPU temperature
- [ ] Monitor GPU frequency
- [ ] No artifacts or crashes
- [ ] Performance stable over time

### Combined Stress (Gaming Simulation)

- [ ] Run demanding game for 1 hour
- [ ] Monitor CPU/GPU temps continuously
- [ ] Verify no thermal throttling
- [ ] FPS stays consistent
- [ ] Battery drain rate measured
- [ ] Case temperature acceptable to hold

### Sustained Gaming Session

- [ ] Play for 2+ hours (if battery allows, or plugged in)
- [ ] No performance degradation
- [ ] No overheating
- [ ] No crashes
- [ ] Controls remain responsive
- [ ] Audio quality maintained

---

## Phase 10: System Health & Stability

### Boot Performance

- [ ] Measure boot time: `systemd-analyze`
- [ ] Boot time <30 seconds (target)
- [ ] Identify slow services: `systemd-analyze blame`

### System Health

- [ ] No errors in dmesg: `dmesg | grep -i error | grep -v "Error: No.*"`
- [ ] No failed services: `systemctl --failed`
- [ ] No critical journal entries: `journalctl -p err -b`
- [ ] No ACPI errors: `dmesg | grep -i acpi.*error`

### Hardware Monitoring

- [ ] All sensors working: `sensors`
- [ ] CPU temperature: `sensors | grep Tctl`
- [ ] GPU temperature: Check via amdgpu sysfs
- [ ] NVMe temperature: `sudo nvme smart-log /dev/nvme0n1 | grep temperature`
- [ ] Battery temperature: `cat /sys/class/power_supply/BAT0/temp` (if available)

### Suspend/Resume Stability

- [ ] Perform 10 suspend/resume cycles
- [ ] All cycles successful
- [ ] No increase in resume time
- [ ] No memory leaks: Check memory usage over time
- [ ] Controllers work after each cycle
- [ ] Can resume games (or restart without issues)

---

## Phase 11: Gaming-Specific Validation

### Controller Support in Games

- [ ] Built-in controls work in all tested games
- [ ] No need to remap controls (Xbox layout standard)
- [ ] Analog sticks smooth in games
- [ ] Triggers have proper analog range
- [ ] Haptic feedback works (if device supports it)

### Online Gaming

- [ ] Can connect to game servers
- [ ] Latency acceptable (<50ms to nearby servers)
- [ ] No disconnections during play
- [ ] Voice chat works (if game supports)
- [ ] Friends list works
- [ ] Multiplayer stable

### Steam Features

- [ ] Steam Cloud saves work
- [ ] Steam overlay works (Shift+Tab)
- [ ] Steam screenshot works
- [ ] Steam Controller configuration works
- [ ] Steam Remote Play works (if configured)
- [ ] Steam Family Sharing works (if used)

### Game Library Management

- [ ] Can install games to NVMe
- [ ] Can move games between drives (if multiple)
- [ ] Game saves preserved
- [ ] Shader cache persists
- [ ] DLC downloads and works

---

## Phase 12: Real-World Usage Testing

### Gaming Session Test

- [ ] Charge to 100%
- [ ] Play demanding game on battery
- [ ] Measure time until 20% battery
- [ ] Calculate battery life
- [ ] Note settings used (TDP, graphics quality)
- [ ] Note average FPS
- [ ] Note thermal behavior

### Portable Use Test

- [ ] Comfortable to hold for extended periods
- [ ] Weight distribution acceptable
- [ ] Controls ergonomic
- [ ] Screen brightness sufficient outdoors (if used outside)
- [ ] Audio audible in different environments
- [ ] Can game on lap, in bed, etc.

### Quick Gaming Test

- [ ] Power on device
- [ ] Launch game
- [ ] Measure time from power on to in-game
- [ ] Target: <60 seconds to gaming

---

## Phase 13: Optional Features

### Game Streaming (Optional)

- [ ] Steam Remote Play from PC to handheld
- [ ] Steam Remote Play from handheld to TV
- [ ] Moonlight game streaming (if configured)
- [ ] Parsec game streaming (if configured)

### External Accessories (Optional)

- [ ] USB-C dock works
- [ ] Keyboard via USB/Bluetooth
- [ ] Mouse via USB/Bluetooth
- [ ] External HDD/SSD
- [ ] USB-C Ethernet adapter (already verified)

### Emulation Testing (If Configured)

- [ ] PS1 games: Full speed
- [ ] PS2 games: Most playable
- [ ] GameCube/Wii: Playable
- [ ] Nintendo DS: Full speed
- [ ] PSP: Full speed
- [ ] Switch: Some games playable (demanding)

---

## Phase 14: Documentation & Optimization

### Performance Documentation

- [ ] Document best settings for popular games
- [ ] Document TDP recommendations
- [ ] Document battery life by game type
- [ ] Document thermal behavior
- [ ] Create optimization guide

### Issues & Workarounds

- [ ] Document any issues found
- [ ] Document fixes applied
- [ ] Note any kernel parameters added
- [ ] Note any custom scripts created
- [ ] Update HARDWARE.md with real-world findings

### Backup & Recovery

- [ ] Create recovery USB with NixOS installer
- [ ] Test booting from recovery USB
- [ ] Document rollback procedure
- [ ] Export working configuration
- [ ] Test rebuilding from flake

---

## Completion Criteria

This system configuration is considered **COMPLETE** when:

### Hardware (Must Pass)

1. ✅ All hardware components detected and functional
2. ✅ No critical errors in dmesg or journalctl
3. ✅ CPU and GPU operating within thermal limits
4. ✅ Battery detection and charging working

### Input (Gaming Critical - Must Pass)

5. ✅ **Built-in gamepad controls 100% functional** (all buttons, sticks, triggers)
6. ✅ Touchscreen working
7. ✅ External controllers supported

### Performance (Gaming Critical - Must Pass)

8. ✅ **Native Linux games run smoothly** (60+ FPS on appropriate settings)
9. ✅ **Proton games work** (Steam compatibility verified)
10. ✅ Graphics drivers stable (no crashes during gaming)
11. ✅ No thermal throttling during normal gaming sessions

### Power (Must Pass for Handheld)

12. ✅ **Battery life ≥ 1.5 hours gaming** at moderate TDP (15W)
13. ✅ Suspend/resume working (can pause gaming, resume later)
14. ✅ Power management functional (CPU/GPU scale properly)

### Gaming Experience (Must Pass)

15. ✅ Steam launches and games install
16. ✅ At least 5 different games tested and playable
17. ✅ Controllers work in all tested games
18. ✅ Audio works in all tested games
19. ✅ Saves work (Steam Cloud or local)

### System Stability (Must Pass)

20. ✅ System stable for 2+ hour gaming session
21. ✅ No crashes or freezes during testing
22. ✅ Can suspend/resume during active gaming

### Quality of Life (Should Pass)

23. ✅ HiDPI scaling makes text readable at handheld distance
24. ✅ Comfortable to hold and play for extended periods
25. ✅ WiFi stable for online gaming
26. ✅ Boot time reasonable (<30 seconds)

---

## Quick Reference: Useful Commands

### Gaming Performance

```bash
# FPS overlay with MangoHud
mangohud %command%  # In Steam launch options

# Gamemode status
gamemoded -s

# GPU info
lspci -k | grep -A3 VGA
cat /sys/class/drm/card0/device/pp_dpm_sclk

# GPU temperature
cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input
```

### Controller Testing

```bash
# List joysticks
ls /dev/input/js*

# Test controller
jstest /dev/input/js0

# List all input devices
cat /proc/bus/input/devices

# Test specific input
evtest
```

### Power Monitoring

```bash
# Battery status
upower -i /org/freedesktop/UPower/devices/battery_BAT0
cat /sys/class/power_supply/BAT0/capacity

# Power consumption
sudo powertop

# CPU frequency
watch -n1 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"

# GPU power state
cat /sys/class/drm/card0/device/power_dpm_state
```

### Thermal Monitoring

```bash
# CPU temperature
cat /sys/class/hwmon/hwmon2/temp1_input
sensors

# GPU temperature
cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input

# All thermal zones
cat /sys/class/thermal/thermal_zone*/temp

# NVMe temperature
sudo nvme smart-log /dev/nvme0n1 | grep temperature
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

# Hardware info
inxi -Fxz
lscpu
lspci -k
```

### Graphics

```bash
# OpenGL info
glxinfo | grep "OpenGL version"
glmark2

# Vulkan info
vulkaninfo --summary
vkcube

# Hardware acceleration
vainfo
```

---

**Last Updated**: 2025-10-27
**Status**: Pre-deployment - Configuration phase
**Next Step**: Review all Priority 1-12 tasks, configure accordingly, then deploy with nixos-anywhere
**Critical**: Built-in gamepad controls MUST work for this to be a functional gaming handheld!
