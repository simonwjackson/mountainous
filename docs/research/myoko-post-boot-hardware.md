# Myoko post-boot hardware findings

## Operating constraints

The user requires native builds on the ASUS, including after the observed lockup. Do not move builds to Fuji without a new user decision. The user also permits Myoko recovery SSH host-key changes after they announce a USB boot. Record and pin the new key for that connection; this permission does not apply to other hosts. Do not spend time on OLED blanking tests at present.

## Verified installed-system failures

| Feature | Direct observation | Scope of conclusion |
| --- | --- | --- |
| Keyboard remapping | `/dev/uinput` is absent, `CONFIG_INPUT_UINPUT` is unset, and Kanata is not running. | The bring-up configuration deliberately disabled remapping. Adding `INPUT_UINPUT=m` and removing that override still requires a matching kernel/modules build and a boot test. |
| Wi-Fi | PCI adapter `17cb:1112`, subsystem `105b:e14f`, loads runtime firmware but fails to find board data for chip ID 33 and board ID 255. NetworkManager exposes no Wi-Fi interface. | Runtime firmware is not the current missing piece. The board-data lookup fails, with and without `variant=UX3407Q`. |
| Sound | `/proc/asound/cards` lists no sound cards. PipeWire and WirePlumber run, but expose only Dummy Output. ADSP firmware is missing and audio supplier devices remain deferred. | This is below the desktop volume controls. Firmware alone is not yet established as a sufficient fix. |

The read-only triage command was `/tmp/myoko-hardware-triage`, which exited 1 with `WIFI_INTERFACE_MISSING`, `ALSA_SOUND_CARD_MISSING`, and `UINPUT_DEVICE_MISSING`. These checks detect device availability, not successful network traffic, audible output, or correct remapped keystrokes.

## Wi-Fi primary-source comparison

- [A16 author report](https://github.com/jc372/A16UbuntuBuild/blob/main/notes/2026-09-16-hermes-wifi-board-data.md) reports the exact PCI IDs and failed lookup keys. The author uses `bdwlan_qcc2072_1p0_ncm820A.elf` from the machine's Windows WLAN package.
- [Second A16 bring-up repository](https://github.com/Hekatomb/LinuxOnAsusUX3607OA) identifies the same file and lookup keys.
- [Author's linux-firmware mailing-list report, mirrored](https://ratatoskr.run/linux-firmware/2026/09/17520689) reports the absent board mapping on UX3407NA and UX3607OA.
- [Related A14 NixOS firmware package](https://github.com/chrispouliot/linux-zenbook-a14-arm/blob/main/pkgs/windows-firmware.nix) installs this ELF as the `ath12k/QCC2072/hw1.0/board.bin` fallback. That is a different laptop and is not by itself a Myoko hardware test.

Myoko's own backed-up Windows INF maps `PCI\VEN_17CB&DEV_1112&SUBSYS_E14F105B` to `QcWlan_AS_NCM820A.ndi`, then to `BD_NCM820A.reg`, whose board filename is `bdwlan_qcc2072_1p0_ncm820A.elf`. That backed-up file has SHA-256 `960e9e93da708f5e1086ce15d82d3e44d846ec9441eac40e1725467d357965d8`.

The exact kernel source in `drivers/net/wireless/ath/ath12k/core.c` tries a direct `board.bin` request after both board-container key lookups fail. A temporary fallback experiment was prepared, but the SSH attempts produced no successful test result. Do not call Wi-Fi fixed. Do not repeat live Wi-Fi module reloads during a kernel build.

## Audio research limit

[The exact-model A16 audio page](https://github.com/jc372/A16UbuntuBuild/blob/main/docs/audio.md) reports internal speakers as not working and calls out missing board integration. This is the author's report, not proof that no local fix is possible. Do not copy the A14 speaker routing or gain settings onto the A16 without board-specific evidence.

The online links above were read from mutable `main` branches. They are research references, not locked build inputs.

## Lockup evidence

The first native keyboard-kernel build lost its SSH connection. It never ran an install or boot-switch command. The user later supplied a photo containing hard-lockup warnings and blocked kernel workers.

USB recovery then read the installed Btrfs root with `ro,rescue=nologreplay`. The journal contains three boot IDs. Explicit `_BOOT_ID` and `_TRANSPORT=kernel` matches were necessary: negative `--boot` offsets on this recovery image returned a misleading message about no persistent journal.

Boot `8334253f0f3c46b296d881150205a2d3` preserves:

- CPU 2 and CPU 6 hard-lockup warnings beginning around 42 seconds.
- Repeated DRM vblank timeout warnings.
- At 242 seconds, workers blocked in `bpf_prog_pack_free`, `bpf_jit_binary_pack_free`, and `bpf_prog_free_deferred`.
- A mutex reported as likely owned by `kworker/1:3:193`.
- NetworkManager waiting in `synchronize_net` and `synchronize_rcu` while closing a packet socket.
- Wi-Fi module loading and a previously unloaded `ath12k` module in the module list.

This identifies blocked paths but does not establish the initiating fault. It does not prove that compiler load, Wi-Fi reload, BPF cleanup, or DRM caused the lockup. No crash record was present in pstore. The latest installed boot in the journal ended with shutdown messages, not the captured lockup.

Copied kernel logs are at `/tmp/myoko-crash-evidence-local` on the controller. Those files are temporary, not durable backups.

## Current build attempt

The native build completed from the ASUS USB recovery system in 977 seconds, with eight compiler jobs and no remote builders. Build output was saved alongside the existing USB kernel log. A preflight failure because recovery Nix lacked enabled experimental features was corrected by passing `--extra-experimental-features 'nix-command flakes'` to the individual commands. No global Nix configuration or boot files were changed for that correction.

The build uses source `/nix/store/jq18hfsq6macrk4p2sn5679s024rjfqz-source` and expects derivation `/nix/store/2mlmkqjnc7lmcv1ddffbn262faqf73i6-nixos-system-myoko-26.11.20260916.b1b8759.drv`. The completed system is `/nix/store/xma54l2i54lz65s93vxlg8nqnglxar31-nixos-system-myoko-26.11.20260916.b1b8759`. The kernel option check passes, including `INPUT_UINPUT=m`. All requested modules resolve against the matching module tree. Kanata's own `--check` command accepts the generated configuration.

The guarded update installed generation 3. Read-only inspection confirmed the installed kernel, DTB, and initrd match the tested outputs. The previous generation remains available. The actual installed initrd passes the storage-driver test. The new kernel is `/nix/store/lmwrcmihb0gqiy01pr0hr0d49d706h4q-linux-7.3-rc3`; its assembled module tree is `/nix/store/cq128mklz7sb74w3p03589jymlkjwpra-linux-7.3-rc3-modules`.

Generation 3 booted from internal storage with Kanata active and `/dev/uinput` present. The user confirmed that keyboard remapping works. This keyboard change is not a proven fix for the lockup.

After login, the panel became black while SSH and Hyprland still responded. The kernel recorded an eDP link-training timeout with `ret=-110` at about 31 seconds. Hyprland reported DPMS on, and the backlight value was nonzero. One display off/on cycle restored the picture, as confirmed by the user. This is a temporary recovery, not a permanent fix. Hyprland uses the Lua dispatch form `hyprctl --instance 0 dispatch 'hl.dsp.dpms({ action = "on" })'`; the legacy `dispatch dpms on` syntax is rejected.

## Reproducible Wi-Fi board-data package

The published Hekatomb board container contains entries for this adapter, but its payload differs from Myoko's own factory backup. The comparison used Qualcomm's `ath12k-bdencoder` to extract the payload. That public file was not installed.

The Myoko host module instead uses `pkgs.requireFile` for the exact factory file. This is a deliberate exception to the preference for external flake inputs: no byte-identical public source was established, and the factory binary must remain outside Git. The Nix expression pins the file by SHA-256. An allow-unfree predicate permits only this named factory file.

Import the file on the native ASUS builder before a build:

```sh
nix-store --add-fixed sha256 /path/to/bdwlan_qcc2072_1p0_ncm820A.elf
```

The controller's source file is:

```text
/persist/backups/myoko-fw-B09A-2505/myoko-firmware/driver-store/qcwlancol8480.inf_arm64_2077838ef4cdffea/bdwlan_qcc2072_1p0_ncm820A.elf
```

Expected size: 125288 bytes. Expected SHA-256: `960e9e93da708f5e1086ce15d82d3e44d846ec9441eac40e1725467d357965d8`.

The package installs this file as `ath12k/QCC2072/hw1.0/board.bin`, which the driver requests after both container-key lookups fail. It does not replace upstream `board-2.bin` or its regulatory data. The small board file stays uncompressed so the installed hash check needs no decompression tool.

`scripts/test-myoko-wifi-firmware <firmware-directory>` fails on the existing firmware tree, where the fallback is absent. The package build runs the same test against its output. The assembled system firmware tree must also pass before installation. Tests of interface creation, scanning, and network traffic remain separate runtime requirements. No live Wi-Fi module reload runs during activation.

Generation 4 installed the factory fallback. Its system is `/nix/store/8xjkgipngvf87bcaa22bnl6i0msi7q79-nixos-system-myoko-26.11.20260916.b1b8759`. The ASUS completed the final system build in 16 seconds without a kernel rebuild. The assembled firmware tree passed the factory hash check. The installed initrd passed the storage-driver test. Kernel and matching modules remained unchanged from generation 3.

After reboot, `wlP4p1s0` appeared and a scan found 21 access points. The user then reported that Wi-Fi works. The scan log also contains regulatory-update timeout warnings; do not describe the driver as error-free. The user also confirmed keyboard remapping works. Sound remains unresolved.

## Bluetooth

The initial system had no BlueZ service, no controller, and no Bluetooth child
under `uart14`. The kernel already included `BT=m`, `BT_HCIUART=m`,
`BT_HCIUART_QCA=y`, `SERIAL_DEV_BUS=y`, and the PCI M.2 power sequencer. The
missing pieces were BlueZ configuration and board device-tree data.

The Myoko host now enables BlueZ and applies a board-only device-tree overlay.
The overlay adds a `qcom,wcn7850-bt` serdev child at 3.2 Mbaud, supplies the six
regulators required by `hci_qca`, and changes `w-disable2-gpios` to active-high.
That polarity makes the power sequencer's initial logical high a physical high,
which deasserts the active-low Bluetooth disable line.

The built artifact test decompiles the final DTB and checks the serdev node,
UART speed, six regulators, GPIO polarity, and BlueZ service. Runtime
verification found controller `C4:13:75:BE:4B:14`, powered and unblocked. The
controller reported product `0x20`, SoC `0x40292100`, ROM `0x00000101`, and
patch `0x7b40`. A 20-second scan discovered nine nearby devices.

The controller requests `qca/hmtbtfw11.tlv`, which neither linux-firmware nor
the factory Windows package contains. The request logs `-2`, then the controller
runs from its ROM firmware and scans successfully. The factory `hmtbtfw20.tlv`
files were tested in an intermediate build but are not requested by this
controller. The final configuration does not carry that unused private firmware
dependency.

Quickshell now uses its native `Quickshell.Bluetooth` API for the top-bar status
and device panel. The panel can power the adapter, scan, pair, connect,
disconnect, forget, and show battery state without calling `bluetoothctl`.
Quickshell 0.3.1 cannot answer authenticated pairing callbacks, so a user
service runs `bt-agent -c NoInputNoOutput`. This supports locally initiated
Just Works pairing. It does not support devices that require entering or
confirming a passkey.

The approved `MX Vertical` mouse paired, bonded, connected, and reported 100%
battery. BlueZ initially logged `input-hog profile accept failed` because the
trimmed kernel did not include UHID. The matching out-of-tree module at
`nix/myoko-uhid.nix` now provides `/dev/uhid` without rebuilding the kernel.
The mouse appeared as `MX Vertical Mouse` on `/dev/input/event13`, and the user
confirmed that pointer movement works.

Keyboard access uses `Super+O`, then `B`. The top bar shows the active chord and
cancels it after three seconds. Inside the Bluetooth panel, Up and Down select a
device, Enter or Space runs its main action, `S` toggles scanning, `P` toggles
adapter power, Shift+Delete forgets a paired device, and Escape closes the
panel. The live Hyprland binding list contains the `Super+O` entry and the `B`
and Escape submap entries. The panel opened, scanned, and rendered in the live
session. Keyboard event handling has static and QML checks but still needs a
user-approved live key test.

## Suspend status

Battery lid close uses `s2idle`. Before sleep, the system enables magic-packet WoWLAN. On resume, a system sleep hook touches `/run/user/1000/myoko-display-resume`. A systemd user path unit waits two seconds and cycles eDP DPMS off and on. The OLED becomes stable about four seconds after lid open. Wi-Fi can take about 25 seconds to reconnect and continues to report regulatory-update timeouts.

The internal `usb@a400000` controller remains disabled. It hosts the Realtek SD reader and caused the SMMU SID `0xda0` and xHCI resume failure. An attached Realtek USB Ethernet adapter caused the separate `usb@a600000` xHCI host to die on resume, so USB Ethernet must be unplugged before sleep. Lid close remains ignored on external power and while docked.

The kernel advertises `deep`, and the complete `pm_test` ladder passed in that mode: `freezer`, `devices`, `platform`, `processors`, and `core`. A real direct deep transition did not complete. The kernel logged `PM: suspend entry (deep)`, offlined CPUs 1 through 17, and then returned `-95` (`EOPNOTSUPP`) from the platform entry. `/sys/power/suspend_stats` recorded one failure with `last_failed_errno=-95`. The PSCI boot log also reports `[Firmware Bug]: failed to set PC mode: -3`. Keep `s2idle` as the default until the platform firmware or kernel gains a working final deep-suspend entry.

## Brightness command

The live Hyprland bindings referenced `brightnessctl`, but Myoko did not have that command. It was installed only by the Galaxy Book3 hardware layer. The shared Hyprland package list now includes it, where its callers live.

The ASUS built system `/nix/store/0ri7lsdx4nhv08pg5gidgdrdp6xgajs2-nixos-system-myoko-26.11.20260916.b1b8759` in 21 seconds. Its kernel and matching modules remain unchanged. A live activation made the command available without a reboot. A command sent through Hyprland as `simon` changed the panel's reported actual brightness from 716 to 737. The test restored 716. Physical brightness-key operation still needs user confirmation.

The live activation also exposed a separate problem. `myoko-console-blank.service` held its start job open while the desktop owned tty1. Its `StandardInput=tty` configuration is consistent with a terminal-acquisition wait. Polkit completed its restart, and SSH and Hyprland still responded. Stopping only the console service removed all pending jobs; the interrupted console service remained marked failed. The configuration still needs a correction before future live activations. No compositor restart or blanking-policy change was made for the brightness test.

## Keyboard backlight

The ASUS keyboard uses an I2C-HID device with ID `0B05:4B42`. After the keyboard
driver loads, the keyboard MCU starts in an autonomous breathing mode. No sysfs
LED existed for it, so nothing in userspace could stop or dim the light.

Three separate defects prevent the stock driver from handling this device:

1. `asus_devices[]` gives `USB_DEVICE_ID_ASUSTEK_I2C_ZENBOOK_KEYBOARD` the
   `I2C_KEYBOARD_QUIRKS | QUIRK_FILTER_CAMERA_COMPANION` flags and omits
   `QUIRK_USE_KBD_BACKLIGHT`. Without that flag `asus_kbd_register_leds` never
   runs.
2. `asus_kbd_get_functions` sends its `0x05 0x20 0x31 0x00 0x08` command in a
   6-byte buffer. This I2C-HID controller requires a 64-byte feature report, so
   the MCU ignores the short command and the read-back returns the earlier
   `asus_kbd_init` handshake string ("ASUS Tech.Inc."). The capability byte
   reads `0x54`, the ASCII 'T' of "Tech", not the real `0x01`. The command and
   read-back both need `FEATURE_KBD_REPORT_SIZE` (64) bytes.
3. The driver delegates LED registration to `asus-wmi`. That driver is x86-only
   and absent on Glymur, so `asus_hid_register_listener` returns `-ENODEV` and
   no LED is created.

The out-of-tree module at `nix/myoko-hid-asus.nix` builds `hid-asus.ko` from the
running kernel's own source plus `modules/glymur/hid-asus/0001-zenbook-a16-backlight.patch`.
The patch:

- sets the 64-byte report size in `asus_kbd_get_functions` and
  `asus_kbd_disable_oobe`;
- adds `QUIRK_USE_KBD_BACKLIGHT` for `0B05:4B42`;
- calls `asus_kbd_disable_oobe` for `0B05:4B42`, which stops the breathing mode;
- registers `asus::kbd_backlight` as a plain `led_classdev` when the WMI
  listener is unavailable, with `max_brightness = 3`;
- restores the saved brightness on resume and turns the LED off on removal.

A live `insmod` of the built module on the running generation produced:

    asus 0018:0B05:4B42.0003: Disabled OOBE for keyboard

and created `/sys/class/leds/asus::kbd_backlight` with `max_brightness` 3.
Writing 0, 1, 2, and 3 to `brightness` all succeeded.

`systemd-backlight@leds:asus::kbd_backlight.service` already exists from
`99-systemd.rules` and saves the value across reboots.

The Zenbook A16 has one keyboard-illumination key. Fn+F4 emits
`KEY_KBDILLUMTOGGLE` (vendor usage `0xc7`), which xkb maps to
`XF86KbdLightOnOff`. It does not emit the `KEY_KBDILLUMUP`/`KEY_KBDILLUMDOWN`
codes that the driver also maps, so a plain up/down binding never fires.
Hyprland binds `XF86KbdLightOnOff` to `kbd-backlight-cycle`, a small script
that steps the LED through 0, 1, 2, 3 and back to 0. The up/down bindings stay
for keyboards that do emit those codes.

`brightnessctl` writes the sysfs `brightness` file as the logged-in user. The
package ships `90-brightnessctl.rules`, but NixOS links a package's udev rules
only when `services.udev.packages` lists it. It was missing, so both the panel
and keyboard backlight files stayed `root:root` and simon got `Operation not
permitted`. `modules/hyprland.nix` now lists `pkgs.brightnessctl` and adds a
rule for `asus::kbd_backlight` that uses the `video` group, because the package's
own LED rule uses the `input` group and adding simon to `input` would grant the
right to read every keypress. The permission model was confirmed live by
applying the same `chgrp video` and `chmod g+w` by hand and running
`brightnessctl` as simon for both the panel and the keyboard LED.
