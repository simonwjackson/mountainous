# Samsung Galaxy Book3 Pro 360 (Model NP960QFG-KA1US) - Hardware Profile

**System Name**: asana
**Hostname**: fuji (current)
**Scan Date**: 2025-10-27
**Target OS**: NixOS

---

## System Overview

- **Manufacturer**: Samsung Electronics Co., Ltd.
- **Model**: 960QFG / NP960QFG-KA1US
- **Product Family**: Galaxy Book3 Pro 360
- **Form Factor**: Convertible/2-in-1 Laptop (Chassis Type 31)
- **BIOS**: American Megatrends International v P04ALN.210.230218.SH (02/18/2023)
- **Serial**: SGLB459A1K-C01-G001-S0002+10.0.22621

---

## Processor

- **CPU**: Intel Core i7-1360P (13th Gen Raptor Lake-P)
- **Architecture**: x86_64
- **Cores**: 12 cores (Hybrid: P-cores + E-cores)
- **Threads**: 16 threads
- **Frequency Range**: 400 MHz - 5000 MHz
- **Cache**:
  - L1d: 448 KiB (12 instances)
  - L1i: 640 KiB (12 instances)
  - L2: 9 MiB (6 instances)
  - L3: 18 MiB
- **Features**:
  - AVX2, AVX-VNNI
  - VT-x (Virtualization Technology)
  - Enhanced Intel SpeedStep
  - Turbo Boost Max 3.0
- **Frequency Scaling**: intel_pstate driver
- **Governor**: performance (currently)
- **BogoMIPS**: 5222.40

### CPU Vulnerabilities Status
- Meltdown: Not affected
- Spectre v1: Mitigated
- Spectre v2: Enhanced/Automatic IBRS
- MDS: Not affected
- Reg file data sampling: Vulnerable (no microcode)

---

## Memory

- **Total RAM**: 16 GB (15920456 kB / 15.9 GB)
- **Type**: LPDDR5 (likely)
- **Configuration**: Soldered (non-upgradeable)
- **NUMA**: Single node (node0)
- **Swap**: 24 GB (zram compression via zram0)

---

## Storage

### Primary Drive
- **Model**: Western Digital WD SN740 NVMe SSD
- **Part Number**: WDSN740-SDDPNQD-1T00-1004
- **Capacity**: 1 TB (953.9 GB)
- **Interface**: NVMe PCIe 4.0
- **Device Path**: /dev/nvme0n1
- **Rotational**: No (SSD)
- **Serial**: 22501B805583
- **EUI**: e8238fa6bf530001001b448b4eaaadae

### Current Disk Layout
- **Partition 1**: 1M (BIOS boot)
- **Partition 2**: 512M FAT32 (/boot)
- **Partition 3**: 953.4G LUKS2 encrypted (fuji-frostbite)
  - Filesystem: Btrfs with subvolumes
  - Impermanence setup active

### Storage Hardware Monitoring
- **Temperature Sensors**:
  - Composite: 29.85°C
  - Sensor 1: 41.85°C
  - Sensor 2: 29.85°C

### Platform Quirks
- **NVMe Simple Suspend**: Platform quirk applied for proper suspend/resume

---

## Graphics

### Integrated GPU
- **Model**: Intel Iris Xe Graphics (Raptor Lake-P)
- **PCI ID**: 0000:00:02.0
- **Vendor/Device**: 0x8086:0xa7a0
- **Subsystem**: Samsung 0x144d:0xc1ca
- **Driver**: i915 (v1.6.0)
- **VT-d**: Active for graphics access

### Firmware
- **DMC**: i915/adlp_dmc.bin v2.20
- **GuC**: i915/adlp_guc_70.bin v70.36.0
- **HuC**: i915/tgl_huc.bin v7.9.3
- **GuC Features**:
  - Submission: Enabled
  - SLPC (Single Loop Power Controller): Enabled
  - RC (Render/Media C states): Enabled
  - HuC authenticated for all workloads

### Display Outputs (DRM Connectors)
- **card1-eDP-1**: Built-in display (connected)
- **card1-HDMI-A-1**: HDMI port
- **card1-DP-1**: DisplayPort/USB-C
- **card1-DP-2**: DisplayPort/USB-C
- **card1-DP-3**: DisplayPort/USB-C
- **card1-DP-4**: DisplayPort/USB-C

### Built-in Display
- **Resolution**: 2880x1800 (3K, 16:10 aspect ratio)
- **Panel Type**: OLED (likely)
- **Touch**: Yes (10-point multi-touch)
- **Pen Support**: Yes (Wacom EMR)
- **Backlight Controller**: intel_backlight
- **Brightness Range**: 0-400
- **Status**: Connected, currently disabled (external display mode?)

### Current i915 Kernel Parameters
```
i915.fastboot=1
i915.force_probe=all
i915.enable_fbc=1
i915.enable_psr=2
```

### Known Graphics Issues
- **Minor**: Selective fetch area calculation fails in pipe A (cosmetic warning)

---

## Audio

### Controller
- **Model**: Intel Alder Lake-P PCH High Definition Audio
- **PCI ID**: 0000:00:1f.3
- **Vendor/Device**: 0x8086:0x51ca
- **Driver**: sof-hda-dsp (Sound Open Firmware)

### Codec
- **Model**: Realtek ALC298
- **Address**: 0
- **Vendor/Device**: 0x10ec0298
- **Subsystem**: Samsung 0x144d:0xc1ca
- **Revision**: 0x100103

### Audio Capabilities
- **Sample Rates**: 44100, 48000, 96000, 192000 Hz
- **Bit Depths**: 16, 20, 24-bit
- **Formats**: PCM

### Audio I/O
- **Headphone Jack**: 3.5mm combo (with detection)
- **Built-in Speakers**: Stereo (AKG-tuned, likely)
- **Built-in Microphones**: Array (noise cancellation capable)
- **HDMI/DisplayPort Audio**: 3 outputs (pcm=3,4,5)

### GPIO Configuration
- **GPIO Pins**: 8 (all currently disabled)

---

## Network

### WiFi
- **Chipset**: Intel Wi-Fi 6E AX211/AX210
- **PCI ID**: 0000:00:14.3
- **Vendor/Device**: 0x8086:0x51f1
- **Subsystem**: 0x8086:0x0094
- **Driver**: iwlmvm (618 KB module)
- **Interface**: wifi (aliases: wlo1, wlp0s20f3, wlxd4d853902b6c)
- **MAC Address**: d4:d8:53:90:2b:6c (randomized: 06:b1:28:a1:f6:e2)
- **Bands**: 2.4GHz, 5GHz, 6GHz (Wi-Fi 6E)
- **Status**: Currently down (no carrier)
- **Temperature Monitoring**: thermal_zone9 (27°C)

### Bluetooth
- **Integrated**: Yes (with WiFi card)
- **Driver**: btusb, btintel
- **Supported Profiles**: RFCOMM, BNEP, CMAC, A2DP, etc.
- **Status**: Active

### Ethernet
- **Type**: USB-C Ethernet Adapter (External)
- **Manufacturer**: Belkin
- **Model**: Belkin USB-C LAN
- **Chipset**: Realtek r8152/r8153
- **Driver**: r8152, r8153_ecm, cdc_ether, usbnet
- **Interface**: enp0s13f0u1 (alias: enxc4411e7613ae)
- **MAC Address**: c4:41:1e:76:13:ae
- **Connection**: USB (connected to USB3 controller at 0000:00:0d.0)
- **Status**: Active (192.168.1.132/24)

### Network Known Issues
- **WiFi Thermal Zone**: Occasionally fails to read (-61 error) - non-critical

---

## Input Devices

### Keyboard
- **Type**: AT Translated Set 2 keyboard
- **Interface**: PS/2 (i8042/serio0)
- **Sysfs Path**: /devices/platform/i8042/serio0/input/input1
- **Event Node**: /dev/input/event1
- **Features**: Full keyboard with function keys
- **Backlight**: Yes (controllable)

### Touchpad
- **Manufacturer**: Imagis
- **Model**: IMG4100:00 4D49:4150
- **Interface**: I2C HID v1.00
- **I2C Bus**: i2c-16 (i2c-IMG4100:00)
- **PCI Controller**: 0000:00:15.0 (i2c_designware.1)
- **Vendor/Product**: 0x4D49:0x4150
- **Driver**: hid-multitouch
- **Event Nodes**:
  - Mouse: /dev/input/event6, /dev/input/mouse0
  - Touchpad: /dev/input/event7, /dev/input/mouse3
- **Features**:
  - Multi-touch gestures
  - Precision touchpad
  - Pressure sensitivity
  - Palm rejection

### Touchscreen
- **Manufacturer**: Goodix
- **Model**: GXTP7936:00 27C6:0123
- **Interface**: I2C HID v1.00
- **I2C Bus**: i2c-17 (i2c-GXTP7936:00)
- **PCI Controller**: 0000:00:15.1 (i2c_designware.2)
- **Vendor/Product**: 0x27C6:0x0123
- **Driver**: hid-multitouch
- **Event Nodes**:
  - Touchscreen: /dev/input/event8, /dev/input/mouse1
  - Additional: /dev/input/event9, /dev/input/event10
- **Features**:
  - 10-point multi-touch
  - 2880x1800 resolution support
  - Palm rejection

### Active Pen/Stylus
- **Manufacturer**: Wacom
- **Model**: WCOM016A:00 2D1F:0185
- **Interface**: I2C HID v1.00
- **I2C Bus**: i2c-18 (i2c-WCOM016A:00)
- **PCI Controller**: 0000:00:15.3 (i2c_designware.3)
- **Vendor/Product**: 0x2D1F:0x0185
- **Technology**: Wacom EMR (Electromagnetic Resonance)
- **Event Node**: /dev/input/event11, /dev/input/mouse2
- **Features**:
  - Pressure sensitivity (high levels)
  - Tilt detection (likely)
  - Hover detection
  - Button support

### Special Input Devices
- **Intel HID Events**: Platform device (INTC1078:00)
  - 5-button array for special functions
  - Event nodes: /dev/input/event2, /dev/input/event3
  - Features: Power button, volume, brightness hotkeys
- **Lid Switch**: ACPI device (PNP0C0D:00)
  - Event node: /dev/input/event4
- **Power Button**: ACPI device (PNP0C0C:00)
  - Event node: /dev/input/event5
- **Video Bus**: LNXVIDEO:00
  - Event node: /dev/input/event0
  - Brightness control events

---

## Sensors (Integrated Sensor Hub)

### ISH Controller
- **Model**: Intel ISH (Integrated Sensor Hub)
- **Device**: Intel ISHTP HID
- **Vendor/Product**: 0x8087:0x0AC2
- **HID Version**: 2.00
- **Interface**: intel_ishtp_hid
- **HID Devices**: 2 sensor hubs

### Available Sensors
1. **3-Axis Accelerometer** (hid_sensor_accel_3d)
   - For screen rotation
   - Motion detection
   - Orientation sensing

2. **3-Axis Gyroscope** (hid_sensor_gyro_3d)
   - Angular velocity
   - Rotation detection
   - Gaming input

3. **Ambient Light Sensor** (hid_sensor_als)
   - Auto-brightness adjustment
   - Display color temperature

4. **Intel Hinge Sensor** (hid_sensor_custom_intel_hinge)
   - **CRITICAL for 2-in-1 functionality**
   - Detects: Laptop, Tablet, Tent, Stand modes
   - Triggers: Touchpad disable, virtual keyboard, rotation lock

### Sensor Framework
- **Framework**: Industrial I/O (IIO)
- **Trigger**: hid_sensor_trigger
- **Buffer**: kfifo_buf, industrialio_triggered_buffer

---

## USB Controllers & Thunderbolt

### xHCI USB Controllers
1. **Controller 0**: 0000:00:0d.0
   - Vendor/Device: 0x8086:0xa71e
   - Version: USB 3.2
   - Quirks: 0x0000000200009810
   - **Associated with Thunderbolt 4**

2. **Controller 1**: 0000:00:0d.2
   - Vendor/Device: 0x8086:0xa73e

3. **Controller 2**: 0000:00:0d.3
   - Vendor/Device: 0x8086:0xa76d

4. **Controller 3** (Main): 0000:00:14.0
   - Vendor/Device: 0x8086:0x51ed
   - Version: USB 3.2
   - Quirks: 0x0000100200009810
   - Most USB devices connect here

### Thunderbolt 4
- **Controller**: Intel Thunderbolt 4 (Alder Lake-P)
- **Module**: thunderbolt (544 KB)
- **Features**:
  - PCIe tunneling
  - DisplayPort tunneling
  - USB tunneling
  - 40 Gbps bandwidth
  - Power Delivery support

### USB Type-C Ports
- **Count**: 2 ports
- **UCSI Controller**: USBC000:00 (platform device)
- **Driver**: ucsi_acpi, typec_ucsi
- **Features**:
  - USB Power Delivery
  - DisplayPort Alt Mode
  - Thunderbolt 4
  - Data + Power
- **Power Supply Devices**:
  - ucsi-source-psy-USBC000:001
  - ucsi-source-psy-USBC000:002

### Connected USB Devices
1. **Belkin USB-C LAN** (USB Ethernet)
   - Connected to USB3 controller
   - Currently active network interface

2. **EGIS Fingerprint Reader** (ETU905A80-E)
   - Vendor: 0xEGIS (likely)
   - USB HID device
   - Located on USB3 bus

3. **PNY USB Flash Drive** (External, removable)
   - Model: USB 3.2.2 FD
   - Size: 465.8 GB
   - Serial: 070836E05B03CC22

---

## Power Management

### Battery
- **Manufacturer**: Samsung Electronics
- **Model**: SR Real Battery
- **Technology**: Li-ion
- **Serial**: 123456789
- **Design Capacity**: 4762 mAh (73.93 Wh @ 15.52V)
- **Full Capacity**: 4700 mAh (72.97 Wh) - **98.7% health**
- **Cycle Count**: 231 cycles
- **Voltage**:
  - Design: 15.52V
  - Current: 15.895V
- **Current State** (at scan time):
  - Status: Charging
  - Charge: 1034 mAh (22%)
  - Current: 2148 mA (charging rate)
- **ACPI Path**: /sys/class/power_supply/BAT1

### AC Adapter
- **ACPI Device**: ADP1
- **Type**: ACPI0003:00
- **Detection**: ACPI-based

### USB-C Power Delivery
- **Ports**: 2 USB-C ports with PD
- **Controller**: UCSI (USB Type-C Connector System Software Interface)
- **Power Roles**: Source and Sink capable
- **Monitoring**: Per-port power supply devices

### Thermal Management

#### Thermal Zones
- **thermal_zone0** (SNS1): 35.05°C
- **thermal_zone1** (INT3400 Thermal): 20.00°C - DPTF Coordinator
- **thermal_zone2** (SNS2): 43.05°C
- **thermal_zone3** (SNS3): 27.05°C
- **thermal_zone4** (acpitz): 41.00°C
- **thermal_zone5** (acpitz): 41.00°C
- **thermal_zone6** (TCPU): 39.00°C
- **thermal_zone7** (TCPU_PCI): 42.00°C
- **thermal_zone8** (x86_pkg_temp): 42.00°C - Package temperature
- **thermal_zone9** (iwlwifi_1): 27.00°C - WiFi temperature

#### Cooling Devices
- **Total**: 18 cooling devices (cooling_device0-17)
- **Types**: CPU frequency scaling, fan control

#### Hardware Monitoring (hwmon)
- **hwmon0**: NVMe drive (Composite: 29.85°C, Sensor 1: 41.85°C, Sensor 2: 29.85°C)
- **hwmon6**: CoreTemp (CPU cores)
  - Core 0: 35°C, Core 4: 36°C, Core 8: 36°C
  - Core 12: 35°C, Core 16: 37°C, Core 17: 37°C
  - Core 18: 37°C, Core 19: 37°C, Core 20: 39°C
  - Core 21: 39°C, Core 22: 40°C, Core 23: 40°C
  - Package: 43°C

#### Intel DPTF (Dynamic Platform and Thermal Framework)
- **ACPI Device**: INT3400
- **Components**:
  - INT3400 Thermal: Coordinator (thermal_zone1)
  - INT3403 Thermal: Sensor
  - processor_thermal_device
  - processor_thermal_rfim: RF interference mitigation
  - processor_thermal_mbox: Mailbox interface
  - processor_thermal_rapl: Power limiting

### Power Management Features
- **CPU Frequency Scaling**: intel_pstate
- **CPU Idle States**: Multiple C-states
- **Display**: Panel Self Refresh 2 (PSR2)
- **Graphics**: Frame Buffer Compression (FBC)
- **PCIe**: ASPM (Active State Power Management)
- **Runtime PM**: Enabled for most devices

---

## PCI Devices Summary

Total PCI devices: 28

### Critical Devices
- **0000:00:00.0**: Host bridge (0x8086:0xa707)
- **0000:00:02.0**: VGA compatible controller - Intel Iris Xe (0x8086:0xa7a0)
- **0000:00:14.0**: USB controller - xHCI (0x8086:0x51ed)
- **0000:00:14.3**: Network controller - WiFi 6E AX211 (0x8086:0x51f1)
- **0000:00:15.0**: Serial bus controller - I2C (Touchpad)
- **0000:00:15.1**: Serial bus controller - I2C (Touchscreen)
- **0000:00:15.3**: Serial bus controller - I2C (Stylus)
- **0000:00:16.0**: Communication controller - MEI (0x8086:0x51e0)
- **0000:00:1f.0**: ISA bridge - PCH (0x8086:0x519d)
- **0000:00:1f.3**: Audio device - HDA (0x8086:0x51ca)
- **0000:00:1f.4**: SMBus (0x8086:0x51a3)
- **0000:00:1f.5**: Serial bus controller - SPI (0x8086:0x51a4)
- **0000:01:00.0**: Non-Volatile memory - WD SN740 NVMe (0x15b7:0x5017)

### Thunderbolt-Related
- **0000:00:0d.0**: USB controller - Thunderbolt 4 (0x8086:0xa71e)
- **0000:00:0d.2**: USB controller (0x8086:0xa73e)
- **0000:00:0d.3**: USB controller (0x8086:0xa76d)
- **0000:00:07.0**: PCI bridge - Thunderbolt (0x8086:0xa76e)
- **0000:00:07.2**: PCI bridge (0x8086:0xa72f)

---

## ACPI & Firmware

### UEFI/BIOS
- **Firmware Type**: UEFI 64-bit
- **Platform Size**: 64-bit
- **Vendor**: American Megatrends International, LLC.
- **Version**: P04ALN.210.230218.SH
- **Release Date**: 02/18/2023
- **EFI Variables**: Available (/sys/firmware/efi/efivars)
- **Secure Boot**: Capable

### ACPI Configuration
- **Total ACPI Devices**: 356
- **RSDP Version**: 2.0 (XSDT)
- **OEM**: SECCSD (Samsung)
- **OEM Table ID**: LH43STAR

### Key ACPI Tables
- **DSDT**: 609,219 bytes - Main system description
- **SSDTs**: Multiple (CPU, GPU, I/O, sensors, thermal)
- **DMAR**: DMA Remapping (VT-d)
- **DPTF**: Dynamic Platform Thermal Framework
- **TPM2**: TPM 2.0 support
- **NHLT**: Non-HD Audio Link Table
- **BGRT**: Boot Graphics Resource Table
- **FPDT**: Firmware Performance Data Table

### ACPI Features
- **Dynamic Tables**: Loaded for CPU, GPU, and thermal management
- **Hot Plug**: Support for USB, Thunderbolt
- **Power States**: S0 (idle), S3 (sleep), S4 (hibernate), S5 (shutdown)
- **Thermal Zones**: 10 zones defined
- **Fan Control**: ACPI-based

### Known ACPI Issues
- **Minor Warning**: `\_SB.PC00.XHCI.RHUB.HS10._DSM` argument type mismatch
  - Expected: Package
  - Found: Integer
  - Impact: None (cosmetic warning)

---

## Loaded Kernel Modules (271 total)

### Graphics & Display
- i915 (4.2 MB) - Intel graphics driver
- drm_display_helper (221 KB)
- drm_buddy, ttm, intel_gtt
- video (77 KB)

### Audio
- snd_sof (434 KB) - Sound Open Firmware
- snd_sof_intel_hda_common (241 KB)
- snd_sof_pci_intel_tgl
- snd_hda_codec_realtek (200 KB)
- snd_hda_codec_hdmi (98 KB)
- soundwire_intel, soundwire_cadence

### Network
- iwlmvm (618 KB) - WiFi driver
- bluetooth (1.09 MB)
- btusb, btintel, btrtl
- r8152 (167 KB) - USB Ethernet

### Input & Sensors
- hid-multitouch - Touchpad & touchscreen
- hid_sensor_hub (28 KB)
- hid_sensor_accel_3d
- hid_sensor_gyro_3d
- hid_sensor_als
- hid_sensor_custom_intel_hinge - **2-in-1 mode detection**
- intel_ishtp_hid (32 KB)
- i2c_hid_acpi

### Power & Thermal
- processor_thermal_device
- processor_thermal_rfim
- intel_rapl_common
- battery (28 KB)
- ucsi_acpi
- intel_powerclamp
- x86_pkg_temp_thermal

### USB & Thunderbolt
- thunderbolt (544 KB)
- xhci_hcd
- typec_ucsi

### Platform
- intel_lpss_pci, intel_lpss
- intel-hid
- i2c_i801 - SMBus

---

## Known Hardware Quirks & Issues

### Applied Workarounds

#### NVMe Suspend Quirk
- **Device**: WD SN740 (0000:01:00.0)
- **Quirk**: Platform quirk for simple suspend
- **Reason**: Prevent NVMe freeze during suspend/resume
- **Status**: Automatically applied by kernel

#### Intel Graphics Parameters
Current kernel command line includes:
```
i915.fastboot=1          # Keep firmware-initialized display
i915.force_probe=all     # Force driver loading even if not in supported list
i915.enable_fbc=1        # Frame Buffer Compression for power saving
i915.enable_psr=2        # Panel Self Refresh 2 for battery life
```

### Known Issues

#### 1. Graphics: Selective Fetch Warning
- **Component**: i915 driver, Pipe A
- **Error**: "Selective fetch area calculation failed in pipe A"
- **Impact**: Cosmetic only, no functional impact
- **Frequency**: Occasional during mode changes
- **Status**: Known upstream issue

#### 2. WiFi: Thermal Zone Read Failure
- **Component**: thermal_zone9 (iwlwifi_1)
- **Error**: "failed to read out thermal zone (-61)"
- **Impact**: WiFi temperature monitoring intermittent
- **Workaround**: None needed, doesn't affect functionality
- **Status**: Non-critical

#### 3. ACPI: USB HID DSM Warning
- **Component**: `\_SB.PC00.XHCI.RHUB.HS10._DSM`
- **Warning**: Argument #4 type mismatch (Integer vs Package)
- **Impact**: None
- **Status**: BIOS/ACPI implementation quirk

#### 4. Bluetooth: Debug Lock
- **Message**: "Bluetooth: hci0: Debug lock is disabled"
- **Impact**: None (informational)

### Potential Linux Compatibility Issues

#### 2-in-1 Mode Detection
- **Dependency**: Intel ISH (Integrated Sensor Hub)
- **Critical Module**: hid_sensor_custom_intel_hinge
- **Userspace**: Requires iio-sensor-proxy or similar
- **Failure Mode**: Manual mode switching if sensors fail
- **Testing Needed**: Rotation, touchpad disable, virtual keyboard

#### Touchscreen Wake Issues
- **Components**: Goodix touchscreen, Wacom stylus
- **Interface**: I2C HID
- **Potential Issue**: May not wake system from sleep
- **Workaround**: USB mouse/keyboard wake, or disable wake on touch
- **Testing Needed**: Suspend/resume with touch wake

#### Sound Firmware
- **Driver**: SOF (Sound Open Firmware)
- **Status**: Relatively new in Linux
- **Potential Issues**:
  - Speaker balance
  - Microphone array configuration
  - HDMI audio routing
- **Tuning**: May need UCM (Use Case Manager) profiles

#### Display Scaling
- **Native Resolution**: 2880x1800 (3K)
- **DPI**: ~226 PPI (assuming 13-15" display)
- **Requirement**: HiDPI/fractional scaling
- **Wayland**: Better HiDPI support
- **X11**: May need manual scaling configuration

---

## Recommended NixOS Configuration

### Hardware Enablement Priority List

1. **Critical (System Boot & Basic Function)**
   - CPU microcode (intel-microcode)
   - Graphics driver (i915)
   - NVMe driver
   - Boot loader configuration
   - Firmware (linux-firmware)

2. **High Priority (Daily Use)**
   - WiFi (iwlwifi)
   - Bluetooth
   - Audio (SOF)
   - Touchpad (libinput)
   - Touchscreen
   - Battery management
   - Backlight control

3. **Medium Priority (2-in-1 Features)**
   - Sensor hub (iio-sensor-proxy)
   - Screen rotation
   - Stylus/pen support
   - Virtual keyboard (onboard)
   - Mode detection (hinge sensor)

4. **Low Priority (Optional Features)**
   - Fingerprint reader
   - Thunderbolt device management
   - HDMI/DisplayPort audio
   - USB-C display output

### Suggested Kernel Parameters
```nix
boot.kernelParams = [
  # Graphics
  "i915.fastboot=1"
  "i915.enable_fbc=1"
  "i915.enable_psr=2"

  # Display
  "video=eDP-1:2880x1800@60"

  # Power management
  "mem_sleep_default=deep"

  # Debugging (remove in production)
  # "drm.debug=0x00"
];
```

### Required Kernel Modules
```nix
boot.initrd.availableKernelModules = [
  "nvme"
  "xhci_pci"
  "thunderbolt"
  "usb_storage"
  "sd_mod"
];

boot.kernelModules = [
  "i915"
  "snd_sof_pci_intel_tgl"
  "iwlmvm"
  "btusb"
  "hid_multitouch"
  "intel_ishtp_hid"
];
```

### Power Management
```nix
# Enable TLP for laptop power management
services.tlp.enable = true;
services.tlp.settings = {
  # Battery conservation
  START_CHARGE_THRESH_BAT0 = 40;
  STOP_CHARGE_THRESH_BAT0 = 80;

  # CPU scaling
  CPU_SCALING_GOVERNOR_ON_AC = "performance";
  CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

  # Intel GPU
  INTEL_GPU_MIN_FREQ_ON_AC = 300;
  INTEL_GPU_MIN_FREQ_ON_BAT = 300;
  INTEL_GPU_BOOST_FREQ_ON_AC = 1500;
  INTEL_GPU_BOOST_FREQ_ON_BAT = 1000;
};

# Thermald for thermal management
services.thermald.enable = true;
```

### Graphics Configuration
```nix
# Enable early KMS
boot.initrd.kernelModules = [ "i915" ];

# Intel graphics
hardware.opengl = {
  enable = true;
  driSupport = true;
  driSupport32Bit = true;
  extraPackages = with pkgs; [
    intel-media-driver # VAAPI
    intel-compute-runtime # OpenCL
    vpl-gpu-rt # VPL
  ];
};
```

### Input Devices
```nix
# Touchpad
services.libinput = {
  enable = true;
  touchpad = {
    naturalScrolling = true;
    tapping = true;
    disableWhileTyping = true;
    accelProfile = "adaptive";
  };
};

# Wacom stylus
services.xserver.wacom.enable = true;
```

### Sensors & 2-in-1 Features
```nix
# Screen rotation
hardware.sensor.iio.enable = true;

# Virtual keyboard for tablet mode
environment.systemPackages = with pkgs; [
  onboard # On-screen keyboard
];
```

---

## Testing Checklist

- [ ] System boots successfully
- [ ] Graphics acceleration working (glxinfo)
- [ ] Display brightness control
- [ ] WiFi connects and stable
- [ ] Bluetooth pairing and audio
- [ ] Audio output (speakers, headphones)
- [ ] Audio input (microphone array)
- [ ] Touchpad gestures
- [ ] Touchscreen multi-touch
- [ ] Stylus pressure and buttons
- [ ] Keyboard all keys + backlight
- [ ] Battery reporting accurate
- [ ] Suspend/resume cycle
- [ ] USB-C data transfer
- [ ] USB-C display output
- [ ] USB-C charging
- [ ] Thunderbolt devices
- [ ] Sensor-based rotation
- [ ] Hinge mode detection
- [ ] Thermal management (no throttling)
- [ ] Webcam (if present)
- [ ] Fingerprint reader (if configured)

---

## References

- **Kernel Version**: 6.6.85 (scanned from running system)
- **NixOS Version**: 25.05.20250406.063dece
- **Scan Date**: 2025-10-27
- **Scan Method**: SSH hardware profiling

## Notes

This is a premium 2-in-1 convertible laptop with excellent Linux hardware support. The 13th Gen Intel platform is well-supported in recent kernels. Most hardware should work out of the box with proper configuration.

Key attention areas:
1. 2-in-1 sensor integration for mode detection
2. Sound firmware tuning (SOF is still maturing)
3. HiDPI display scaling configuration
4. Power management tuning for battery life
