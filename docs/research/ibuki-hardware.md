# Ibuki hardware profile

Collected on 2026-09-29 through the Hiyori recovery USB. The target is an Intel NUC8i3BEK, not the Samsung machine described by Hiyori's hardware layer.

Ibuki was installed on the internal SSD later that day. The profile below records the earlier recovery-system scan. See the installation result for installed-system checks.

The first sample used `simon@hiyori`. The deeper scan used verified root SSH access. Passwordless sudo for Simon is unavailable, but root SSH works. No disk was formatted, mounted for inspection, or repaired. No configuration changed. Diagnostic packages were fetched into the recovery system's Nix store. No stress test, storage benchmark, or SMART self-test ran.

## Evidence

Raw files are in `docs/research/ibuki-hardware-profile.tar.gz`. Extract the archive into `/tmp` to read the `ibuki-hardware-profile/` directory. These are command outputs collected from the machine, not an inferred specification. Commands used the repository's locked nixpkgs revision `4975466d324710c576dc11ad614684e6bd8cad8e`.

```sh
tar -xzf docs/research/ibuki-hardware-profile.tar.gz -C /tmp
```

## Hardware

| Component | Verified identity | Evidence |
|---|---|---|
| System | Intel NUC8i3BEK, SKU BOXNUC8i3BEK, version J72748-306 | `dmi.txt` |
| Board | Intel NUC8BEB, version J72693-307 | `dmi.txt` |
| Firmware | Intel BECFL357.86A.0085.2020.1007.1917, dated 2020-10-07 | `dmi.txt` |
| Processor | Core i3-8109U, 2 cores, 4 threads, 3.0 GHz nominal, 3.6 GHz maximum | `cpu.txt` |
| CPU frequency control | `intel_pstate`, `powersave`, 400 MHz to 3.6 GHz | `cpu_frequency.txt` |
| Virtualization | VT-x exposed by the CPU | `cpu.txt` |
| Memory | One 8 GiB DDR4 SO-DIMM, Crucial CT8G4SFS8266.M8FD, configured at 2400 MT/s | `dmi.txt` |
| Memory expansion | SODIMM1 empty; firmware reports 32 GiB maximum across two slots | `dmi.txt` |
| Integrated graphics | Iris Plus Graphics 655, PCI `8086:3ea5`, driver `i915` | `pci.txt` |
| Graphics firmware | `i915/kbl_dmc_ver1_04.bin`, version 1.4 loaded | `kernel_log.txt` |
| Internal SSD | Kingston SUV500M8240G, M.2 SATA, 240,057,409,536 bytes | `smart_sata.txt` |
| SATA controller | Intel AHCI, PCI `8086:9dd3`, driver `ahci` | `pci.txt` |
| Onboard Ethernet | Intel I219-V, PCI `8086:15be`, driver `e1000e`; link down | `pci.txt`, `network_eno1.txt` |
| Active Ethernet | Realtek USB RTL8156B, driver `r8152`, 2500 Mb/s full duplex | `network_enp108s0u1.txt`, `network_driver_enp108s0u1.txt` |
| Wi-Fi | Intel Wireless-AC 9560 160MHz, PCI `8086:9df0`, driver `iwlwifi`; interface down | `kernel_log.txt`, `pci.txt`, `network.txt` |
| Wi-Fi firmware | `9000-pu-b0-jf-b0-46.ucode`, version 46.7e3e4b69.0 | `kernel_log.txt` |
| Bluetooth | Intel controller with `btusb`, `intel/ibt-17-16-1.sfi` firmware | `usb_tree.txt`, `kernel_log.txt` |
| Audio | Intel HDA PCH with Realtek ALC233 analog codec and three HDMI playback devices | `audio_playback.txt` |
| Thunderbolt | Intel JHL6340 Alpine Ridge Thunderbolt 3 bridges and USB controller | `pci.txt` |
| Card reader | Realtek RTS522A, PCI `10ec:522a`, driver `rtsx_pci` | `pci.txt` |
| Display | LG TV on DRM DP-1, preferred EDID mode 3840x2160 at 60 Hz; connector detected but disabled | `edid_card1-DP-1.txt`, `display_card1-DP-1.txt` |
| TPM | Intel TPM 2.0, firmware 403.1; systemd reports TPM support | `dmi.txt`, `tpm.txt`, `boot.txt` |

Detected hardware and loaded drivers do not prove Wi-Fi association, Bluetooth pairing, audio output, suspend, or display rendering works. Those functions were not exercised.

## Storage and boot

At scan time, the recovery system ran NixOS 26.11 with kernel 6.18.52. It booted through UEFI with Secure Boot disabled. Systemd did not report a measured UKI or measured OS.

| Disk | Purpose at scan time | Layout at scan time |
|---|---|---|
| `/dev/sda` | Internal Kingston SSD, no mounted partitions | 1 GiB FAT ESP, 1 GiB ext4 boot, 221.6 GiB Btrfs root |
| `/dev/sdb` | PNY 500 GB Hiyori recovery USB | BIOS partition, FAT ESP, LUKS2 root containing Btrfs |

At scan time, the internal SSD held a partitioned installation. Being unmounted did not mean it was empty. Its data was not inspected before installation erased it.

The exact internal SSD identity is:

```text
/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D
```

The recovery USB identity is:

```text
/dev/disk/by-id/usb-PNY_USB_3.2.2_FD_070836E05B03CC22-0:0
```

The USB connects through `uas` at 10 Gbit/s. The Ethernet adapter uses a separate Thunderbolt USB controller and connects at USB 5 Gbit/s. USB link rates are not storage or network throughput measurements.

The USB LUKS enrollment has one password slot and no TPM slot. Ibuki uses an unencrypted root on the internal SSD. The recovery USB keeps its encryption.

### Internal SSD health

SMART reports PASSED. It reports 6,811 power-on hours and a percentage-used endurance indicator of 3. Reallocated sectors, pending sectors, reported uncorrectable errors, and interface CRC errors are zero. Temperature is 33 C.

It also reports eight runtime bad blocks and 140 unexpected power losses. No errors or self-tests are logged. These counters do not establish an active disk failure. SMART is not a full media test.

SMART could not identify the PNY USB bridge automatically. USB media health remains unknown.

### Existing partition-label collision

At scan time, both drives used the `disk-main-*` namespace. At scan time, `/dev/disk/by-partlabel/disk-main-ESP` pointed to the internal SSD, while `disk-main-root` pointed to the USB. Earlier boot logs show an initial LUKS superblock failure on `disk-main-root`, followed by a successful unlock.

The duplicate labels are verified. Their role in the failed unlock is inferred, not proven. Ibuki needs its own `ibuki` disk namespace so its installed system cannot select the recovery USB by an ambiguous label.

## Runtime sample

The first sample showed 7.6 GiB usable RAM, 1.3 GiB used, and 6.4 GiB available. No swap is configured. The recovery root had 7.8 GiB used out of about 465 GiB. System and user failed-unit lists were empty.

The deeper scan collected ten seconds of `vmstat`, five live intervals of `iostat`, and six seconds of per-CPU `mpstat`. These were sequential observations, not a controlled benchmark. Package fetching before the sample affected the recovery system's caches and resource use.

I/O wait was abnormal in that recovery sample. The six-second per-CPU sample averaged 25.85% aggregate I/O wait. CPU 2 reported 98.16% I/O wait, while total user and system execution averaged 0.42% and 1.04% respectively. I/O pressure reported `some avg10=91.91` and `full avg10=88.99`.

The disk sample does not show saturation. Several live intervals recorded no block I/O. One interval wrote 352 KiB through the USB with 0.12 ms average write latency and 0.10% utilization. No thread in the captured thread list had state D.

The pressure counters and block activity do not establish a faulty or slow USB drive. The cause remains unresolved. The installed SSD sample below did not reproduce this behavior.

## Firmware and security observations

Firmware reports a 2020 BIOS date. This scan did not check whether a newer firmware release exists. One ACPI thermal zone reports an invalid negative temperature, and the kernel logs `No valid trip points!`. Other thermal zones report plausible values. During the deeper scan, the CPU package reported 50 C and the chipset reported 52 C.

The CPU reports mitigations for several speculative-execution vulnerabilities. L1TF, MDS, and MMIO stale-data status still include `SMT vulnerable`. No security policy or SMT setting changed.

No encryption is the user's explicit choice. Its cost is that anyone with physical access to the SSD can read its data and retained credentials. TPM support is available but is not required for this installation.

## Host configuration

The user selected an unencrypted internal install with no GUI yet. The intended workload is light gaming and a Jellyfin client. The configuration lives in `modules/hosts/ibuki.nix` and adds `nixosConfigurations.ibuki` to the existing flake. It imports the shared `base`, `disk`, and `server` layers. No separate nested flake is needed.

The host enables Intel microcode updates and `thermald`. The shared base provides firmware and AHCI support. PCI and USB drivers probe automatically. No Samsung laptop layer or desktop layer is imported. Graphics libraries are enabled separately, so a later GUI and player can use the GPU.

| Setting | Ibuki configuration |
|---|---|
| Platform | `x86_64-linux` |
| Install disk | Verified Kingston `ata-` by-id path above |
| Disk namespace | `ibuki` |
| Partition table | GPT |
| Boot | UEFI systemd-boot, firmware boot entry enabled |
| ESP | 1 GiB FAT, mounted at `/boot` |
| Root | Remaining space, unencrypted Btrfs |
| Subvolumes | `/@`, `/@home`, `/@nix` |
| Mount options | `compress=zstd:1`, `noatime` |
| Remote access | Key-only OpenSSH and shared Tailscale setup |
| Desktop | None; the user will configure it later |
| Graphics | Mesa Iris OpenGL and Intel ANV Vulkan, 64-bit and 32-bit |
| Video acceleration | Intel `iHD` VA-API driver, 64-bit and 32-bit |
| Early graphics | `i915` in the initrd |
| Render access | Simon belongs to `render` as well as the shared `video` group |
| Diagnostic tools | `vainfo`, `vulkaninfo`, `intel_gpu_top` |
| Sleep, suspend, hibernate | Disabled by the server layer |
| Bluetooth | Disabled by the server layer |

Hiyori keeps its own encrypted configuration. Creating Ibuki does not migrate or remove encryption from that USB.

The user approved using `cairn`. The local `main` branch points to a different 2025 layout, and `git merge-base main cairn` found no shared ancestor. This work is not merged into that unrelated branch.

## Verification

Run the install-plan test and build the system without accessing the target disk:

```sh
./scripts/test-ibuki-install-plan
nix build .#nixosConfigurations.ibuki.config.system.build.toplevel
```

The test evaluates the real NixOS configuration. It checks the exact SSD identity, unique labels, unencrypted Btrfs layout, empty LUKS device list, UEFI boot, no GUI, microcode, thermal service, and unchanged Hiyori encryption. It also checks both graphics architectures, Intel media drivers, render access, diagnostic tools, early `i915`, and the absence of a forced GuC parameter.

The initial test failed because Ibuki did not exist. After adding the host, the test passed and the complete NixOS system built. The built system uses kernel 6.18.53. These initial build checks did not prove that Ibuki boots on the NUC. Installation and boot checks followed later that day.

## Graphics and client validation

The live GPU test used the candidate Ibuki graphics libraries on the NUC while it still ran Hiyori's recovery kernel 6.18.52. It ran as `simon`, without a GUI, against the Intel PCI render node. It did not replace Hiyori's `/run/opengl-driver`, change device permissions, or activate the Ibuki system. Copying the libraries added store paths to the recovery USB.

Probe output is in `docs/research/ibuki-gpu-validation.txt`, with trailing spaces removed. The reusable test is `scripts/test-ibuki-gpu-target`.

| Check | Verified result |
|---|---|
| Hardware identity | Intel `8086:3ea5`, kernel `i915` |
| Vulkan device | Iris Plus Graphics 655, Mesa 26.2.3, Intel ANV, device API 1.4.354 |
| Software renderer exclusion | Test selects the Intel ANV ICD, not lavapipe |
| Video driver | Intel iHD 26.2.4, VA-API 1.24 |
| H.264 8-bit decode | Twelve synthetic frames decoded through VA-API, zero decode errors |
| HEVC 10-bit decode | Twelve synthetic frames decoded through VA-API, zero decode errors |
| VP9 8-bit decode | Twelve synthetic frames decoded through VA-API, zero decode errors |
| VP9 10-bit capability | Driver exposes `VAProfileVP9Profile2` decode; no 10-bit VP9 clip was tested |
| GPU clock ceiling | Allowed maximum and boost are 1050 MHz, equal to hardware RP0 |
| Built graphics libraries | Iris, ANV, and iHD are ELF64 in the normal driver directory and ELF32 in the 32-bit directory |

The decoding test requires VA-API hardware frames and downloads them with FFmpeg's `hwdownload` filter. Software decoding cannot pass that filter. Each generated clip has twelve 160x96 frames. This verifies actual hardware decoding, not 4K throughput or playback quality.

Vulkan enumeration is not a game-rendering benchmark. No FPS, game launch, 32-bit game runtime, presentation, HDR output, tone mapping, audio synchronization, or Jellyfin player was tested. The full NixOS build, flake evaluation, install-plan test, ShellCheck, and Nix formatting passed. The installation result below adds actual SSD boot checks.

To repeat the GPU check, run this from a repository checkout on Ibuki. FFmpeg is a temporary test dependency, not a permanently installed player:

```sh
nix shell --inputs-from . nixpkgs#ffmpeg --command bash scripts/test-ibuki-gpu-target
```

### Driver and performance choices

Use Mesa for OpenGL and Vulkan, and `intel-media-driver` for video decoding. The selected Intel driver supports Coffee Lake. There is no global driver override, so future applications keep normal device selection. The probe narrows the driver selection only for its own process.

Do not add `vpl-gpu-rt`, legacy `i965`, or OpenCL solely for client playback. The current OneVPL GPU runtime targets newer Intel generations. Client decoding through VA-API does not require it. Jellyfin server transcoding settings do not configure a Jellyfin client. The later player must select hardware decoding and support the video's codecs.

This GPU does not provide AV1 hardware decoding. AV1 needs software decoding or server transcoding to a supported codec. H.264 10-bit is also absent from the driver's decode profiles. HEVC 10-bit decoding does not by itself prove HDR display output works.

Keep automatic CPU and GPU frequency control and `thermald`. Do not force an always-on performance governor, raise the GPU minimum clock, disable security mitigations, or add `i915.enable_guc=3`. Those changes are not measured improvements here and can increase heat, fan noise, or compatibility risk. GuC/HuC low-power encoding setup is not needed for this client-decoding workload.

The hardware change I recommend first is a second compatible 8 GiB DDR4 SO-DIMM. The current scan shows one empty channel and one 8 GiB module at 2400 MT/s. A matching second module provides 16 GiB and dual-channel system RAM. More memory bandwidth can help integrated-GPU games, but no FPS improvement was measured. This costs another module and a physical installation. The NUC's two CPU cores and graphics hardware remain performance limits.

The shared server layer still disables Bluetooth. Wireless controllers need that policy changed later. No Steam, Jellyfin server, display manager, or desktop was added.

Sources checked:

- [Intel media-driver supported platforms and codecs](https://github.com/intel/media-driver).
- [NixOS graphics module at the locked revision](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/hardware/graphics.nix).
- [Jellyfin Intel hardware notes](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel/). This describes server acceleration; only its hardware-generation limits are used here.

## Installation result

Installed and verified on 2026-09-29, after the user approved erasing the internal SSD. Installation used the running Hiyori recovery system. No kexec was needed. The generated disko script selected only the verified Kingston by-id path. The NixOS closure and new host key went into the SSD mounted at `/mnt`. Native `nixos-install` installed systemd-boot.

The installed source is `cairn` commit `ee9c4982`. The running system matches this exact closure:

```text
/nix/store/6pnspqpd3v1al7nghyxyz1w2yrsyjh4q-nixos-system-ibuki-26.11.20260923.4975466
```

Ibuki has a separate SSH host key. Its age recipient was added to the fleet rule. Cryptographic checks verified decryption with Ibuki, Hiyori, Tate, Myoko, and the master key. The decrypted payload did not change. Installation and boot both generated the required credential files without printing their contents.

```text
SSH Ed25519: SHA256:NTYp6RljPrX9L9yZPFtRhK4TGKxzGE48LxaHLSJ/i9M
Age recipient: age139z7cqp2vf8x8vgzcdax3v7adf5xgkv8757tznlkkv7v57cj430svkm0sp
```

| Installed-system check | Verified result |
|---|---|
| Hardware | NUC8i3BEK, serial `G6BE0100075M` |
| Kernel | `6.18.53` |
| Root | Kingston SSD, `/dev/sda2[/@]`, unencrypted Btrfs, `disk-ibuki-root` |
| Boot | Internal FAT ESP, `/dev/sda1`, `disk-ibuki-ESP` |
| Firmware entry | `0003`, ESP UUID `78965bcb-0ed8-4bac-83dc-00c9f62fefa6`; still first in BootOrder after the second boot |
| Recovery USB | Partition table and EFI loader hash unchanged; no USB partitions mounted after boot |
| SSH | Key-verified access as root and Simon; `simon@ibuki` resolves and works |
| Network | USB Ethernet, `192.168.1.174` |
| Tailscale | Registered as `ibuki`, `100.96.31.114` |
| Credentials | OAuth and user-password files exist with mode `0400` and root ownership |
| Services | OpenSSH, NetworkManager, Tailscale, and thermald active; zero failed system units |
| Graphics | 64-bit and 32-bit Iris, ANV, and iHD driver files available; Simon has render access |
| GPU execution | Intel ANV Vulkan enumeration and H.264, HEVC 10-bit, VP9 VA-API decoding passed as Simon |
| Desktop and Korri | Disabled; no Steam, Jellyfin server, or player configured |

The first idle sample showed 627 MiB RAM used and 7.0 GiB available. Five live `vmstat` intervals showed 100% idle CPU and 0% I/O wait. CPU, memory, and I/O pressure all had `avg10=0.00`. This short sample does not explain the earlier recovery-system anomaly or prove sustained performance.

A second SSD boot succeeded without a BootNext override. The verification process took 418 seconds before completion. Systemd measured 49.948 seconds from firmware startup through userspace. The recovery USB was no longer detected after that boot. The cause of the extra delay and USB absence is unknown. This does not prove normal SSD boot priority with the USB connected.

Installed-system and GPU outputs from both boots are in `docs/research/ibuki-installed-validation.txt`. Machine IDs and the tailnet domain are omitted. GPU clips remain small synthetic tests, not game or 4K playback benchmarks.

Connect with:

```sh
ssh -F /dev/null simon@ibuki
```

## Reinstallation boundary

CAUTION: running the disk installer again erases the installed SSD and its data. The recovery USB is not an install target. Reinstallation needs separate approval and a backup decision. Use normal NixOS rebuilds for updates.

Keep Ibuki's host identity at `~/.local/share/mountainous/hostkeys/ibuki/`. Do not reuse Hiyori's host key. A replacement identity needs a new fleet recipient and decryption checks before installation.

The base layer uses SOPS for fleet credentials. SOPS encrypts the credential file in Git, not Ibuki's disk. Unencrypted storage exposes the SSH private key and retained credentials to anyone with physical access. No SSD backup ran before the approved installation.

Do not activate the Ibuki configuration on the Hiyori recovery USB with `nixos-rebuild switch`. Its filesystem labels refer to the internal SSD.
