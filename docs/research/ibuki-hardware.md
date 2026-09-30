# Ibuki hardware profile

Collected on 2026-09-29 through the Hiyori recovery USB. The target is an Intel NUC8i3BEK, not the Samsung machine described by Hiyori's hardware layer.

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

The recovery system runs NixOS 26.11 with kernel 6.18.52. It boots through UEFI with Secure Boot disabled. Systemd does not report a measured UKI or measured OS.

| Disk | Current purpose | Current layout |
|---|---|---|
| `/dev/sda` | Internal Kingston SSD, no mounted partitions | 1 GiB FAT ESP, 1 GiB ext4 boot, 221.6 GiB Btrfs root |
| `/dev/sdb` | PNY 500 GB Hiyori recovery USB | BIOS partition, FAT ESP, LUKS2 root containing Btrfs |

The internal SSD already holds a partitioned installation. Being unmounted does not mean it is empty. Its data was not inspected.

The exact internal SSD identity is:

```text
/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D
```

The recovery USB identity is:

```text
/dev/disk/by-id/usb-PNY_USB_3.2.2_FD_070836E05B03CC22-0:0
```

The USB connects through `uas` at 10 Gbit/s. The Ethernet adapter uses a separate Thunderbolt USB controller and connects at USB 5 Gbit/s. USB link rates are not storage or network throughput measurements.

The current USB LUKS enrollment has one password slot and no TPM slot. The requested Ibuki configuration will use an unencrypted root. That does not remove encryption from the existing recovery USB.

### Internal SSD health

SMART reports PASSED. It reports 6,811 power-on hours and a percentage-used endurance indicator of 3. Reallocated sectors, pending sectors, reported uncorrectable errors, and interface CRC errors are zero. Temperature is 33 C.

It also reports eight runtime bad blocks and 140 unexpected power losses. No errors or self-tests are logged. These counters do not establish an active disk failure. SMART is not a full media test.

SMART could not identify the PNY USB bridge automatically. USB media health remains unknown.

### Existing partition-label collision

Both drives use the `disk-main-*` namespace. At scan time, `/dev/disk/by-partlabel/disk-main-ESP` pointed to the internal SSD, while `disk-main-root` pointed to the USB. Earlier boot logs show an initial LUKS superblock failure on `disk-main-root`, followed by a successful unlock.

The duplicate labels are verified. Their role in the failed unlock is inferred, not proven. Ibuki needs its own `ibuki` disk namespace so its installed system cannot select the recovery USB by an ambiguous label.

## Runtime sample

The first sample showed 7.6 GiB usable RAM, 1.3 GiB used, and 6.4 GiB available. No swap is configured. The recovery root had 7.8 GiB used out of about 465 GiB. System and user failed-unit lists were empty.

The deeper scan collected ten seconds of `vmstat`, five live intervals of `iostat`, and six seconds of per-CPU `mpstat`. These were sequential observations, not a controlled benchmark. Package fetching before the sample affected the recovery system's caches and resource use.

I/O wait remains abnormal. The six-second per-CPU sample averaged 25.85% aggregate I/O wait. CPU 2 reported 98.16% I/O wait, while total user and system execution averaged 0.42% and 1.04% respectively. I/O pressure reported `some avg10=91.91` and `full avg10=88.99`.

The disk sample does not show saturation. Several live intervals recorded no block I/O. One interval wrote 352 KiB through the USB with 0.12 ms average write latency and 0.10% utilization. No thread in the captured thread list had state D.

The pressure counters and block activity do not establish a faulty or slow USB drive. The cause remains unresolved. A fresh internal installation needs a new idle sample before performance claims are made.

## Firmware and security observations

Firmware reports a 2020 BIOS date. This scan did not check whether a newer firmware release exists. One ACPI thermal zone reports an invalid negative temperature, and the kernel logs `No valid trip points!`. Other thermal zones report plausible values. During the deeper scan, the CPU package reported 50 C and the chipset reported 52 C.

The CPU reports mitigations for several speculative-execution vulnerabilities. L1TF, MDS, and MMIO stale-data status still include `SMT vulnerable`. No security policy or SMT setting changed.

No encryption is the user's explicit choice. Its cost is that anyone with physical access to the SSD can read its data and retained credentials. TPM support is available but is not required for this installation.

## Host configuration

The user selected an SSH-only host on the internal Kingston SSD, with no disk encryption. The configuration lives in `modules/hosts/ibuki.nix` and adds `nixosConfigurations.ibuki` to the existing flake. It imports the shared `base`, `disk`, and `server` layers. No separate nested flake is needed.

The host enables Intel microcode updates and `thermald`. The shared base provides firmware and AHCI support. PCI and USB drivers probe automatically. No Samsung laptop layer or desktop layer is imported.

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
| Desktop | None |
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

The test evaluates the real NixOS configuration. It checks the exact SSD identity, unique labels, unencrypted Btrfs layout, empty LUKS device list, UEFI boot, headless services, microcode, thermal service, and unchanged Hiyori encryption.

The initial test failed because Ibuki did not exist. After adding the host, the test passed and the complete NixOS system built. The built system uses kernel 6.18.53. These checks do not prove that Ibuki boots on the NUC. No install, activation, or reboot was attempted.

## Installation boundary

CAUTION: installing Ibuki erases the internal SSD's existing partitions and data. The recovery USB is not an install target. Installation needs separate approval and a backup decision.

Before installation, create a separate Ibuki SSH host identity with `./scripts/host-key ibuki`. Add its printed age recipient to `.sops.yaml`, then run `./scripts/secrets --rekey`. Verify that the new key decrypts `secrets/fleet.yaml` without printing its contents. Do not reuse Hiyori's host key. This identity and recipient setup was not performed as part of creating the configuration.

The base layer still uses SOPS for fleet credentials. That encrypts the credential file in Git, not Ibuki's disk. Unencrypted storage exposes the SSH private key and other retained credentials to anyone with physical access.

After identity provisioning and explicit disk-erasure approval, the repository's remote installer command is:

```sh
./scripts/install-remote ibuki root@hiyori
```

Do not use `nixos-rebuild switch` to activate this configuration on the currently booted Hiyori USB. The Ibuki filesystem labels do not exist until the internal disk is installed. After installation, boot the internal SSD and collect new failed-unit, mount, network, and I/O-pressure checks.
