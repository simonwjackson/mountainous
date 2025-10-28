# AYANEO AIR - Hardware Profile

**System Name**: hotaka
**Hostname**: hotaka
**Scan Date**: 2025-10-27
**Target OS**: NixOS
**IP Address**: 192.168.1.132

---

## System Overview

- **Manufacturer**: AYANEO
- **Model**: AIR
- **Product Family**: AYANEO
- **Form Factor**: Handheld Gaming PC (Chassis Type 30)
- **Board**: AIR (P02)
- **BIOS**: American Megatrends International, LLC. v V1.04_P4C9M43L4_16GB (08/16/2022)
- **BIOS Release**: 5.19
- **EC Firmware Release**: 4.70
- **Serial**: [Not disclosed]
- **SKU**: AYANEO

---

## Processor

- **CPU**: AMD Ryzen 5 5560U with Radeon Graphics
- **Architecture**: x86_64
- **CPU Family**: 25 (Zen 3)
- **Model**: 80
- **Stepping**: 0
- **Cores**: 6 cores
- **Threads**: 12 threads
- **Frequency Range**: 400 MHz - 4062 MHz
- **Frequency Boost**: Enabled
- **Current Scaling**: 32% (variable)
- **BogoMIPS**: 4591.74
- **Cache**:
  - L1d: 192 KiB (6 instances)
  - L1i: 192 KiB (6 instances)
  - L2: 3 MiB (6 instances)
  - L3: 8 MiB (1 instance)
- **Features**:
  - AVX2, AES, SHA-NI
  - AMD-V (Virtualization)
  - SME (Secure Memory Encryption)
  - VAES, VPCLMULQDQ
  - RDRAND, RDSEED
- **NUMA**: Single node (node0)

### CPU Vulnerabilities Status
- Gather data sampling: Not affected
- Itlb multihit: Not affected
- L1tf: Not affected
- Mds: Not affected
- Meltdown: Not affected
- Mmio stale data: Not affected
- Reg file data sampling: Not affected
- Retbleed: Not affected
- Spec rstack overflow: Mitigation; Safe RET
- Spec store bypass: Mitigation; Speculative Store Bypass disabled via prctl
- Spectre v1: Mitigation; usercopy/swapgs barriers and __user pointer sanitization
- Spectre v2: Mitigation; Retpolines; IBPB conditional; IBRS_FW; STIBP always-on; RSB filling
- Srbds: Not affected
- Tsx async abort: Not affected

### Current CPU Temperature
- **Tctl**: 46.5°C (at scan time)

---

## Memory

- **Total RAM**: 13 GB (12.9 GB / 13175340 kB)
- **Type**: DDR4 (likely)
- **Configuration**: Soldered (non-upgradeable)
- **NUMA**: Single node (node0)
- **Swap**: 16 GB (zram compression via zram0)
- **Memory at Scan**:
  - Used: 1.7 GB
  - Free: 9.6 GB
  - Available: 11.3 GB
  - Cached: 1.5 GB

---

## Storage

### Primary Drive
- **Model**: NVME SSD 512GB
- **Serial**: 2208VC0S036H0498
- **Capacity**: 512 GB (476.9 GB)
- **Interface**: NVMe PCIe
- **Device Path**: /dev/nvme0n1
- **Rotational**: No (SSD)

### Current Disk Layout
- **Partition 1**: 1M (BIOS boot)
- **Partition 2**: 512M (FAT32, /boot)
- **Partition 3**: 476.4G (Btrfs, encrypted with frostbite)
  - Mount: /tundra/frostbite/snowscape/gaming/profiles
  - Filesystem: Btrfs

### Storage Hardware Monitoring
- **hwmon0**: NVMe temperature monitoring available

---

## Graphics

### Integrated GPU
- **Model**: AMD Radeon Graphics (Cezanne)
- **PCI ID**: 0000:04:00.0
- **Vendor/Device**: 0x1002:0x1638
- **Class**: VGA compatible controller (0x030000)
- **Driver**: amdgpu
- **Module Size**: 15.9 MB

### Display Outputs (DRM Connectors)
- **card1-eDP-1**: Built-in display (internal)
- **card1-DP-1**: DisplayPort/USB-C
- **card1-DP-2**: DisplayPort/USB-C

### Built-in Display
- **Native Resolution**: 1920x1080 (7" diagonal)
- **Orientation**: Portrait (shows as 1080x1920 in native mode)
- **Panel Type**: IPS LCD
- **Touch**: Yes (Goodix Capacitive TouchScreen)
- **Status**: Currently disabled (external display mode or power saving)

### Supported Display Modes
- 1080x1920 (native portrait)
- 720x1280
- 720x1152
- 1024x768
- 768x1024

### Current Kernel Parameters
```
amdgpu.ppfeaturemask=0xffffffff
amdgpu.gpu_recovery=1
amd_pstate=active
```

---

## Audio

### HDMI/DisplayPort Audio
- **Controller**: HD-Audio Generic HDMI/DP
- **PCI ID**: 0000:04:00.1
- **Vendor/Device**: 0x1002:0x1637
- **Class**: Audio device (0x040300)
- **Outputs**:
  - pcm=3 (HDMI/DP)
  - pcm=7 (HDMI/DP)

### Analog Audio
- **Controller**: AMD Family 17h/19h HD Audio Controller
- **PCI ID**: 0000:04:00.6
- **Vendor/Device**: 0x1022:0x15e3
- **Class**: Audio device (0x040300)
- **Built-in Microphone**: Yes
- **Headphone Jack**: 3.5mm combo jack

### Audio Devices
- Built-in Speakers: Stereo
- Built-in Microphone: Mono
- Headphone Jack Detection: Yes

---

## Network

### WiFi
- **Chipset**: MediaTek MT7921
- **PCI ID**: 0000:02:00.0
- **Vendor/Device**: 0x14c3:0x0608
- **Class**: Network controller (0x028000)
- **Driver**: mt7921e, mt7921_common, mt792x_lib, mt76_connac_lib, mt76
- **Module**: mt7921e (24 KB), mt7921_common (98 KB), mt76 (139 KB)
- **Interface**: wlp2s0
- **MAC Address**: 10:6f:d9:29:8e:97 (permanent)
- **Randomized MAC**: aa:0e:d2:a6:ad:bf
- **Bands**: 2.4GHz, 5GHz, 6GHz (WiFi 6E)
- **Standards**: 802.11ax (WiFi 6E)
- **Status**: Currently down (no carrier)
- **Temperature Monitoring**: hwmon5 (mt7921_phy0)

### Bluetooth
- **Integrated**: Yes (with WiFi card)
- **Driver**: btusb, btintel, btrtl, btbcm, btmtk
- **Supported Profiles**: RFCOMM, BNEP, CMAC
- **Status**: Active

### Ethernet
- **Type**: USB-C Ethernet Adapter (External)
- **Manufacturer**: Belkin
- **Model**: Belkin USB-C LAN
- **Chipset**: Realtek r8152/r8153
- **Driver**: r8152, r8153_ecm, cdc_ether, usbnet
- **Interface**: enp4s0f4u1 (alias: enxc4411e7613ae)
- **MAC Address**: c4:41:1e:76:13:ae
- **Connection**: USB3
- **Status**: Active (192.168.1.132/24)

---

## Input Devices

### Keyboard
- **Type**: AT Translated Set 2 keyboard
- **Interface**: PS/2 (i8042/serio0)
- **Event Node**: /dev/input/event0
- **Features**: Full keyboard support

### Touchscreen
- **Manufacturer**: Goodix
- **Model**: Goodix Capacitive TouchScreen
- **Interface**: I2C (GDIX1002:00)
- **Vendor/Product**: 0x0416:0x039f
- **Version**: 0x0040
- **Driver**: hid-multitouch
- **Event Nodes**: /dev/input/event9, /dev/input/mouse2
- **Features**:
  - Multi-touch support
  - Capacitive touch
  - Touch pressure detection
  - Palm rejection

### Gamepad Controls
- **Built-in Controls**: Integrated gaming controls
- **Layout**: Handheld gaming PC format
  - Analog sticks
  - D-pad
  - Action buttons (ABXY)
  - Shoulder buttons (L1/R1, L2/R2)
  - System buttons (menu, view, etc.)

### External Gamepad
- **Type**: Xbox 360 Controller (USB)
- **Manufacturer**: ZhiXu
- **Model**: Microsoft X-Box 360 pad
- **Vendor/Product**: 0x045e:0x028e
- **Driver**: xpad
- **Event Node**: /dev/input/event5, /dev/input/js0
- **Features**: Force feedback support
- **Status**: Currently connected

### Special Input Devices
- **Lid Switch**: ACPI device (PNP0C0D:00)
  - Event node: /dev/input/event6
  - Detects open/close state
- **Power Button**: ACPI device (PNP0C0C:00)
  - Event node: /dev/input/event7, event10
- **Video Bus**: LNXVIDEO
  - Event node: /dev/input/event8
  - Brightness control events

---

## Sensors

### Available Sensors
The system has integrated sensors through ACPI but specific sensor details are limited on this handheld device.

### Sensor Framework
- **Framework**: Standard ACPI
- **Lid Switch**: Present (for detecting open/closed state)

---

## USB Controllers

### xHCI USB Controllers
1. **Controller 1**: USB 3.2 Host Controller
   - Multiple USB3/USB2 ports available
   - 4 xHCI host controllers detected

### Connected USB Devices
1. **ZhiXu Controller** (Xbox 360 Controller)
   - External gamepad
   - USB connection
   - Force feedback enabled

2. **MediaTek Wireless Device** (WiFi/BT)
   - Integrated WiFi 6E and Bluetooth
   - Internal USB connection

3. **Belkin USB-C LAN** (Ethernet Adapter)
   - USB to Ethernet adapter
   - Realtek chipset
   - Currently active network interface

---

## Power Management

### Battery
- **Manufacturer**: Amd Battery
- **Model**: Li-ion Real Battery
- **Technology**: Li-ion
- **Serial**: 123456789
- **Design Capacity**: 28297 mWh (28.3 Wh)
- **Full Capacity**: 28297 mWh (28.3 Wh) - **100% health**
- **Cycle Count**: 0 cycles (new or reset counter)
- **Voltage**:
  - Design: Not specified
  - Current: 11.55V
- **Current State** (at scan time):
  - Status: Charging
  - Charge: 26310 mWh (92%)
  - Power: 8327 mW (charging rate)
- **ACPI Path**: /sys/class/power_supply/BAT0

### AC Adapter
- **ACPI Device**: ADP1
- **Type**: ACPI0003:00
- **Detection**: ACPI-based
- **Connection**: USB-C Power Delivery

### USB-C Power Delivery
- **Ports**: 2 USB-C ports with PD
- **Power Delivery**: USB-C PD capable
- **Charging**: Support for USB-C PD chargers

### Thermal Management

#### Hardware Monitoring (hwmon)
- **hwmon0**: NVMe temperature
- **hwmon1**: ADP1 (AC adapter)
- **hwmon2**: k10temp (CPU temperature sensor)
  - Tctl: 46.5°C at scan time
- **hwmon3**: BAT0 (Battery)
- **hwmon4**: oxpec (Embedded controller)
- **hwmon5**: mt7921_phy0 (WiFi temperature)
- **hwmon6**: amdgpu (GPU temperature)

### Power Management Features
- **CPU Frequency Scaling**: amd_pstate (active)
- **CPU Idle States**: Multiple C-states
- **GPU Power Management**: AMD GPU dynamic power management
- **Runtime PM**: Enabled for most devices

---

## PCI Devices Summary

Total PCI devices: 29

### Critical Devices
- **0000:00:00.0**: Host bridge (AMD Cezanne)
- **0000:00:01.0**: PCI bridge
- **0000:00:02.0**: PCI bridge (WiFi)
- **0000:00:08.0**: PCI bridge
- **0000:00:08.1**: PCI bridge (GPU)
- **0000:00:14.0**: SMBus controller
- **0000:00:14.3**: ISA bridge (Embedded controller)
- **0000:00:18.x**: Host bridge (Data Fabric, 8 functions)
- **0000:01:00.0**: Non-Volatile memory controller - NVMe SSD
- **0000:02:00.0**: Network controller - MediaTek MT7921 WiFi 6E
- **0000:04:00.0**: VGA compatible controller - AMD Radeon (Cezanne)
- **0000:04:00.1**: Audio device - AMD HDMI/DP Audio
- **0000:04:00.2**: Encryption controller - AMD FCH
- **0000:04:00.3**: USB controller - AMD USB 3.1
- **0000:04:00.4**: USB controller - AMD USB 3.1
- **0000:04:00.5**: Multimedia controller
- **0000:04:00.6**: Audio device - AMD Family 17h/19h HD Audio

---

## ACPI & Firmware

### UEFI/BIOS
- **Firmware Type**: UEFI (assumed)
- **Platform Size**: 64-bit
- **Vendor**: American Megatrends International, LLC.
- **Version**: V1.04_P4C9M43L4_16GB
- **Release Date**: 08/16/2022
- **BIOS Release**: 5.19
- **EC Firmware**: 4.70

### ACPI Configuration
- **OEM**: AYANEO
- **Chassis Type**: 30 (Tablet/Handheld)

### ACPI Features
- **Power States**: S0 (idle), S3 (sleep), S4 (hibernate), S5 (shutdown)
- **Lid Switch**: Present
- **Power Button**: Present
- **Battery Management**: Full ACPI battery support
- **Thermal Zones**: Multiple zones for CPU, GPU, battery

---

## Loaded Kernel Modules

### Graphics & Display
- amdgpu (15.9 MB) - AMD graphics driver
- drm modules

### Audio
- snd_sof (483 KB) - Sound Open Firmware
- snd_sof_amd_* (multiple modules for AMD audio)
- snd_pci_ps, snd_amd_sdw_acpi
- soundwire_amd

### Network
- mt7921e (24 KB) - WiFi driver
- mt7921_common (98 KB)
- mt792x_lib (69 KB)
- mt76_connac_lib (94 KB)
- mt76 (139 KB)
- mac80211 (1.7 MB)
- bluetooth (1.1 MB)
- btusb, btintel, btrtl, btbcm, btmtk

### USB Ethernet
- r8152 (172 KB) - Realtek USB Ethernet
- r8153_ecm
- cdc_ether
- usbnet (65 KB)

### Input & Sensors
- hid_multitouch (36 KB) - Touchscreen
- xpad (49 KB) - Xbox controller
- ff_memless (20 KB) - Force feedback

### Other
- rfcomm, bnep - Bluetooth protocols
- qrtr - Qualcomm IPC Router
- nf_tables - Netfilter
- algif_hash, algif_skcipher, af_alg - Crypto

---

## Known Hardware Quirks & Issues

### Applied Workarounds

#### AMD GPU Parameters
Current kernel command line includes:
```
amdgpu.ppfeaturemask=0xffffffff  # Enable all power features
amdgpu.gpu_recovery=1            # Enable GPU hang recovery
amd_pstate=active                # Use active P-state driver
```

### Known Issues

#### 1. Display Orientation
- **Component**: Built-in 7" display
- **Issue**: Native portrait orientation (1080x1920)
- **Impact**: May need rotation for proper handheld orientation
- **Workaround**: Use display rotation settings in desktop environment
- **Status**: Expected behavior for handheld device

#### 2. Battery Cycle Count
- **Component**: Battery reporting
- **Issue**: Cycle count shows as 0
- **Impact**: Cannot track battery wear accurately
- **Status**: Common on ACPI battery implementations

#### 3. Limited Sensor Data
- **Component**: Hardware sensors
- **Issue**: Accelerometer/gyroscope not detected
- **Impact**: No automatic screen rotation based on device orientation
- **Status**: May require specific drivers or kernel modules

### Potential Linux Compatibility Issues

#### Handheld Controls Integration
- **Components**: Built-in gamepad controls
- **Potential Issue**: May need specific input mapping
- **Recommendation**: Test all buttons and analog inputs
- **Tools**: evtest, jstest-gtk
- **Userspace**: May need controller mapping profiles

#### Display Scaling
- **Native Resolution**: 1920x1080 on 7" display
- **DPI**: ~314 PPI
- **Requirement**: HiDPI/fractional scaling
- **Wayland**: Better HiDPI support recommended
- **X11**: May need manual scaling configuration (150-200% scale)

#### Power Management
- **Component**: AMD Ryzen 5 5560U
- **Consideration**: Handheld TDP limits
- **Recommendation**: Configure TDP limits for battery life vs performance
- **Tools**: RyzenAdj (if available), TLP, auto-cpufreq

#### WiFi Performance
- **Chipset**: MediaTek MT7921
- **Status**: Good Linux support in recent kernels
- **Potential Issues**:
  - WiFi 6E may need recent kernel (5.18+)
  - Power saving modes may affect performance
- **Recommendation**: Test WiFi stability and performance

---

## Recommended NixOS Configuration

### Hardware Enablement Priority List

1. **Critical (System Boot & Basic Function)**
   - CPU microcode (amd-microcode)
   - Graphics driver (amdgpu)
   - NVMe driver
   - Boot loader configuration
   - Firmware (linux-firmware)

2. **High Priority (Daily Use)**
   - WiFi (mt7921e)
   - Bluetooth
   - Audio (SOF for AMD)
   - Touchscreen (libinput)
   - Battery management
   - Backlight control

3. **Medium Priority (Gaming Features)**
   - Gamepad support (xpad for external controllers)
   - Steam/gaming software
   - GPU performance tuning
   - TDP management

4. **Low Priority (Optional Features)**
   - External display support
   - USB-C display output
   - Advanced power management

### Suggested Kernel Parameters
```nix
boot.kernelParams = [
  # AMD GPU
  "amdgpu.ppfeaturemask=0xffffffff"
  "amdgpu.gpu_recovery=1"

  # AMD P-state
  "amd_pstate=active"

  # Power management
  "mem_sleep_default=deep"

  # Quiet boot (optional)
  "loglevel=4"
];
```

### Required Kernel Modules
```nix
boot.initrd.availableKernelModules = [
  "nvme"
  "xhci_pci"
  "usb_storage"
  "sd_mod"
  "sdhci_pci"
];

boot.kernelModules = [
  "amdgpu"
  "kvm-amd"
  "mt7921e"
  "btusb"
  "hid_multitouch"
];
```

### Graphics Configuration
```nix
# Enable early KMS
boot.initrd.kernelModules = [ "amdgpu" ];

# AMD graphics
hardware.opengl = {
  enable = true;
  driSupport = true;
  driSupport32Bit = true;
  extraPackages = with pkgs; [
    amdvlk
    rocm-opencl-icd
    rocm-opencl-runtime
  ];
  extraPackages32 = with pkgs; [
    driversi686Linux.amdvlk
  ];
};

# Vulkan
hardware.amdgpu.opencl.enable = true;
```

### Power Management
```nix
# Enable TLP for handheld power management
services.tlp.enable = true;
services.tlp.settings = {
  # Battery conservation for handheld
  CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
  CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

  # CPU boost
  CPU_BOOST_ON_AC = 1;
  CPU_BOOST_ON_BAT = 0;

  # AMD GPU
  RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
  RADEON_DPM_PERF_LEVEL_ON_BAT = "low";

  # USB autosuspend (be careful with controllers)
  USB_AUTOSUSPEND = 1;
};

# Alternatively, use auto-cpufreq for better handheld power management
services.auto-cpufreq.enable = true;
services.auto-cpufreq.settings = {
  charger = {
    governor = "schedutil";
    turbo = "auto";
  };
  battery = {
    governor = "powersave";
    turbo = "never";
    scaling_min_freq = 400000;
    scaling_max_freq = 2400000;
  };
};
```

### Input Devices
```nix
# Touchscreen
services.libinput = {
  enable = true;
  touchpad = {
    naturalScrolling = false;
    tapping = true;
    disableWhileTyping = false;  # Handheld device, no traditional typing
  };
};

# Gamepad support
hardware.xpadneo.enable = true;  # For Xbox controllers
hardware.xone.enable = false;    # Not needed for this device

# Steam input (for gaming)
programs.steam.enable = true;
```

### Display Configuration
```nix
# HiDPI settings for 7" 1080p display
services.xserver.dpi = 314;  # Calculated for 7" 1920x1080

# Wayland recommended for better scaling
programs.hyprland.enable = true;  # Or your preferred Wayland compositor

# X11 alternative
services.xserver = {
  enable = true;
  displayManager = {
    # Your choice of display manager
  };
  # Scale factor
  dpi = 314;
};
```

### Audio Configuration
```nix
# PipeWire recommended for gaming
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
  jack.enable = true;
};
```

### Gaming Optimizations
```nix
# Gamemode for performance when gaming
programs.gamemode.enable = true;

# Steam
programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;
  dedicatedServer.openFirewall = false;
};

# Enable 32-bit libraries for gaming
hardware.opengl.driSupport32Bit = true;

# Proton GE for better game compatibility
programs.steam.package = pkgs.steam.override {
  extraPkgs = pkgs: with pkgs; [
    gamemode
    mangohud
  ];
};
```

---

## Testing Checklist

### Basic System
- [ ] System boots successfully
- [ ] Graphics acceleration working (glxinfo, vulkaninfo)
- [ ] Display brightness control
- [ ] Audio output (speakers, headphones)
- [ ] WiFi connects and stable
- [ ] Bluetooth pairing
- [ ] Battery reporting accurate
- [ ] Suspend/resume cycle
- [ ] Power button functionality
- [ ] Volume controls

### Display
- [ ] Built-in display works
- [ ] Correct display orientation
- [ ] HiDPI scaling appropriate
- [ ] Brightness keys functional
- [ ] External display via USB-C
- [ ] Display rotation (if needed)

### Input
- [ ] Touchscreen multi-touch
- [ ] Touchscreen accuracy
- [ ] Built-in gamepad controls
  - [ ] Left analog stick
  - [ ] Right analog stick
  - [ ] D-pad
  - [ ] ABXY buttons
  - [ ] Shoulder buttons (L1/R1)
  - [ ] Triggers (L2/R2)
  - [ ] Menu/view buttons
  - [ ] System buttons
- [ ] External gamepad (USB/Bluetooth)
- [ ] Keyboard input (on-screen or external)

### Network
- [ ] WiFi connection stable
- [ ] WiFi 6E support (if available)
- [ ] Bluetooth pairing (headphones, controllers)
- [ ] USB Ethernet adapter
- [ ] Network performance

### Gaming
- [ ] Steam launches
- [ ] Native Linux games
- [ ] Proton games
- [ ] Controller input in games
- [ ] GPU performance (frame rates)
- [ ] Fan noise levels
- [ ] Thermal management (no throttling)
- [ ] Battery life during gaming

### Power Management
- [ ] Accurate battery percentage
- [ ] Battery charge/discharge rates
- [ ] USB-C charging
- [ ] USB-C PD negotiation
- [ ] Sleep/wake functionality
- [ ] Hibernate (if enabled)
- [ ] TDP management
- [ ] Fan control

### Advanced
- [ ] Performance mode switching
- [ ] TDP limiting for battery life
- [ ] GPU compute (OpenCL/ROCm)
- [ ] External USB devices
- [ ] USB-C data transfer
- [ ] Firmware updates (if available)

---

## References

- **Kernel Version**: 6.12.28 (scanned from running system)
- **NixOS Version**: 25.11.20250518.292fa7d
- **Scan Date**: 2025-10-27
- **Scan Method**: SSH hardware profiling
- **IP Address**: 192.168.1.132

## Notes

This is a handheld gaming PC with excellent Linux hardware support. The AMD Ryzen 5 5560U (Zen 3) platform with integrated Radeon graphics is well-supported in recent kernels. Most hardware should work out of the box with proper configuration.

Key attention areas:
1. Display scaling configuration for 7" 1080p screen (very high DPI)
2. Gamepad controls mapping and testing
3. Power management tuning for battery life vs performance
4. TDP configuration for optimal gaming performance
5. Audio configuration for built-in speakers
6. WiFi 6E support verification
7. Suspend/resume stability testing

The device is particularly well-suited for:
- Handheld gaming (native and emulation)
- Portable workstation
- Media consumption
- On-the-go development

Recommended desktop environment: Wayland-based compositor with good HiDPI support (Hyprland, GNOME, or KDE Plasma 6) or a gaming-focused interface like Gamescope/Steam Deck UI.
