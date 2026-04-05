# Kita — NixOS Anywhere Prep (not executed yet)

## Goal

Prepare `192.168.1.175` for a future `nixos-anywhere` install as host `kita`,
without actually switching it yet.

## Probed facts

- Reachability: only reachable via `rakku`
- Current installer login: `nixos@192.168.1.175`
- Current installer auth: password login works
- Machine: `Intel NUC8i3BEK`
- CPU: `Intel Core i3-8109U`
- Boot mode: `UEFI`
- Active network path in installer: `enp108s0u1` on `192.168.1.175/24`
- Target disk: `/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D`
- Display state during probe: `card1-DP-1` connected, `3840x2160` available

## Repo changes already prepared

- `hosts/kita/default.nix`
- `hosts/kita/hardware.nix`
- `hosts/kita/disko.nix`
- `flake.nix` includes `kita`
- repo-managed host SSH key generated:
  - `secrets/keys/hosts/x86_64-linux_kita_ssh_host_rsa_key.age`
  - `secrets/keys/hosts/x86_64-linux_kita_ssh_host_rsa_key.pub`

## Host intent currently encoded

- host name: `kita`
- Yuki-like Btrfs layout (no disk encryption)
- `device.role = "kiosk"`
- Chromium user service launches Jellyfin in kiosk mode
- some desktop niceties disabled for a leaner TV/kiosk image:
  - `codexbar`
  - `dictation`
  - `evdev-hotkey`
  - `matrix-notifications`

## Non-destructive validation already run

### Config build

Succeeded:

```bash
nix build .#nixosConfigurations.kita.config.system.build.toplevel --no-link --print-out-paths
```

Produced:

```bash
/nix/store/1czcjyrvmd3ia5w5gsd790ayp8z04h93-nixos-system-kita-26.05.20260313.c06b4ae
```

### VM disko test

This originally failed when `kita` used interactive LUKS. `kita` no longer uses
full-disk encryption, so the expected next validation step is to rerun the VM
`disko` test against the non-encrypted layout.

## When we are ready to install

### 1. Sanity check installer reachability

```bash
ssh -F /dev/null -J rakku nixos@192.168.1.175
```

### 2. Recommended: let the x86_64 target do the x86_64 build

Use `--build-on remote` rather than relying on an ARM machine to build the full
system closure.

### 3. Example raw `nixos-anywhere` command

If using password auth from the installer environment:

```bash
export SSHPASS='REDACTED'

/nix/store/jv3gggjq30s4s4dpg7axzgfpnvk05z71-nixos-anywhere-1.13.0/bin/nixos-anywhere \
  --flake .#kita \
  --target-host nixos@192.168.1.175 \
  --env-password \
  --build-on remote \
  --ssh-option ProxyJump=rakku \
  --ssh-option StrictHostKeyChecking=no \
  --ssh-option UserKnownHostsFile=/dev/null
```

## Notes / open follow-up

- We have **not** executed `nixos-anywhere` yet.
- We may still want to further lock down kiosk UX before install:
  - remove/override more Hyprland bindings
  - hide the bar
  - decide whether the kiosk should point at tailnet Jellyfin or a local/LAN URL
- If we want the repo `deploy` wrapper to be the primary install path later, it
  should be taught about `ProxyJump=rakku` and password-driven installs.
