# Asama before arrival

`asama` is Simon's Nubia Red Magic 11 Pro, NX809J: Snapdragon 8 Elite Gen 5
(SM8850, Kaanapali, downstream `canoe`), 24 GB RAM, 1216×2688 portrait.
Nothing has been installed. **Do not use the fleet installer.** It delegates
partitioning to disko. Replacing the UFS partition table would destroy modem
state, calibration and boot firmware. The host rejects disko and the installer
refuses `asama` before it contacts a target. NixOS is the only planned OS;
there is no install layout. The Linux `linux` and `linux-esp` partition labels
are placeholders, not instructions. The Linux ESP is not Canoe's `efisp`.

## Boot and hardware

The port's path is ABL → Canoe in `efisp` → Mu-Silicium UEFI → systemd-boot.
The loader passes the NX809J device tree to the EFI-stub kernel. `fastboot boot`
does not work. `nx809j-mainline` at `feb8ea8` publishes the config fragment
and patch series; `linux/` is a separate repository. The kernel input matches
the final commit in that series. Mountainous uses arm64 defconfig plus the
fragment and its own NixOS initrd, not the bring-up ramdisk or its USB shell.

UFS and ext4 are built in. In stage 1, after the labelled root mounts, the
phone reads `modemst1`, `modemst2`, `fsc` and `fsg` into private regular files
under `/var/lib/rmtfs` on that root. Existing copies are kept. After switch-root,
`rmtfs -s -o /var/lib/rmtfs` serves only those copies. No raw-partition mode.

Upstream reports the panel, DP alt mode, touch, Adreno 840 (Freedreno/Turnip),
UFS, USB, Wi-Fi, Bluetooth, audio, modem data, battery, game slider and s2idle
working. No deep suspend, haptics, fingerprint enrolment or cameras. This is a
port status report, not a test of Simon's hardware.

**Still needed:** delivery of the phone-specific signed firmware and calibration.
The port lists the exact names in `scripts/firmware-files.sh`: remoteproc and IPA
images, modem profiles, Adreno ZAP, PEACH Wi-Fi, Brahma Bluetooth and audio
tuning. Only the distribution's redistributable GPU microcode is expected from
linux-firmware. No device dumps, modem files or proprietary blobs belong in Git
or a public Nix cache. Confirm labels, firmware delivery, fleet enrollment and
the framebuffer-to-MSM splash handover on arrival.

## Session and design guest

`asama` uses Korri's nixpkgs and does **not** take Denial yet. At `01b588e`, Denial's
Nix outputs are x86_64-only. The ARM64 runtime engine matches upstream's SHA-256
(`af2435ed14ce971fc249eaf2aa7bd2e5a0ef963069794db69396cb3c88a0fcff`).
Upstream does not pin an ARM Dart SDK and matching `gen_snapshot` to build
the shell. The blocker is the build toolchain, not the runtime engine. Korri's Sway
runs headless so it does not compete for Denial's seat. Controller/dock/slider
mode switching and nested Sway are later work.

`asama-vm` uses Denial's mobile profile. Only the guest enables the implicit
scanout patch and uses a QEMU with the Vulkan loader on its search path.
From this checkout on Zao:

```sh
vm=$(scripts/asama-vm/build.sh)
scripts/asama-vm/run-on-myoko.sh "$vm"
scripts/asama-vm/guest.sh 'systemctl --user start tarn && journalctl --user -u tarn -n 10 --no-pager'
```

The VM has its own disk image under `~/asama-vm` on Myoko. The SSH port is
on Myoko's loopback only. Tarn connects over Myoko's NAT to tarn-service on
Rakku (`ws://100.88.212.117:4790`). Do not enroll the design guest or give it
a fleet decryption key.
