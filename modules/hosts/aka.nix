# AMD Ryzen tower with a Radeon RX 7900 (Navi 31) and no monitor: a Korri
# streaming source and a fleet builder. In-place port from `unified`.
#
# Do not add the shared `disk` layer, disko, or an installer to this host.
# The two NVMe drives hold a btrfs RAID0 with live data; the mounts below
# describe it as it is. An assertion keeps disko out.
{ inputs, ... }:
let
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII39/0ibgjRrTpAHgDu2oBDUPwEC/7mBwey3Km7ZNR5z";
in
{
  fleet.builders.aka = {
    cpus = 12;
    speedFactor = 4;
    features = [
      "big-parallel"
      "benchmark"
      "kvm"
      "nixos-test"
    ];
    inherit hostKey;
    # Room for a stream and its game before builds.
    memoryHigh = "50%";
    memoryMax = "60%";
  };
  fleet.hostKeys.aka = hostKey;

  nixos.hosts.aka = {
    system = "x86_64-linux";
    # modules/korri.nix: the Korri product needs Korri's own nixpkgs.
    nixpkgs = inputs.korri.inputs.nixpkgs;
    layers = [
      "server"
      "korri"
    ];

    module =
      {
        config,
        lib,
        options,
        pkgs,
        ...
      }:
      let
        root = "/dev/disk/by-partlabel/disk-nvme1-root";
        btrfs = subvol: {
          device = root;
          fsType = "btrfs";
          options = [
            "compress=zstd"
            "noatime"
            "space_cache=v2"
            "subvol=${subvol}"
          ];
        };
      in
      {
        # The live layout, with the device names of the running fstab so a
        # switch does not remount anything. `@persist` and `@games` are empty
        # and stay on disk unmounted.
        fileSystems = {
          "/" = btrfs "@";
          "/nix" = btrfs "@nix";
          "/home" = btrfs "@home";
          "/.snapshots" = btrfs "@snapshots";
          "/boot" = {
            device = "/dev/disk/by-partlabel/disk-nvme0-ESP";
            fsType = "vfat";
            options = [ "umask=0077" ];
          };
        };
        # Plain swap. Aka does not hibernate (the server layer turns sleep off).
        swapDevices = [ { device = "/dev/disk/by-partlabel/disk-nvme0-swap"; } ];

        # The second NVMe carries a spare ESP. Copy /boot to it after each
        # install, so the machine still boots if nvme0 dies.
        boot.loader.systemd-boot.extraInstallCommands = ''
          mkdir -p /boot/efi-backup
          if ! ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
            ${pkgs.util-linux}/bin/mount /dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup || true
          fi
          # Copy only onto a mounted ESP. Without the mount, rsync would copy
          # /boot into itself and fill it.
          if ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
            ${pkgs.rsync}/bin/rsync -a --delete --exclude='/efi-backup' /boot/ /boot/efi-backup/
            ${pkgs.util-linux}/bin/umount /boot/efi-backup || true
          else
            echo "efi-backup: spare ESP not mounted; skipped the copy" >&2
          fi
        '';

        boot.initrd.kernelModules = [ "amdgpu" ];
        boot.kernelModules = [ "kvm-amd" ];
        hardware.cpu.amd.updateMicrocode = true;
        # Korri product devices run the Linux 7.2 series.
        boot.kernelPackages = pkgs.linuxPackages_7_2;
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };

        # Wake from off over the wired Intel I225-V.
        networking.interfaces.eno1.wakeOnLan.enable = true;

        # Korri hardware facts. There is no monitor, but an HDMI dummy plug
        # (EDID 'FH-HD4K') sits in the RX 7900's HDMI-A-1. Korri accepts
        # Sunshine's virtual input only on the DRM backend, so the compositor
        # drives that plug. The board also has a Raphael iGPU (PCI 0f:00.0);
        # the RX 7900 is 03:00.0. Card numbers follow probe order, so name
        # the GPU by PCI path.
        services.korriLinuxHost.compositor = {
          backend = "drm";
          drmDevice = "/dev/dri/by-path/pci-0000:03:00.0-card";
          renderDevice = "/dev/dri/by-path/pci-0000:03:00.0-render";
          outputName = "HDMI-A-1";
          mode = "1920x1080@60Hz";
        };

        # simon holds UID 1000, Korri's default for its runtime account
        # (see ibuki.nix). 56774 matches ibuki.
        services.korriProduct.runtimeAccount.uid = 56774;

        # Korri requires USB gadget facts. A tower has no USB device
        # controller, so the unit stays off.
        services.korriProduct.usbGadget = {
          name = "aka";
          product = "Aka NixOS";
          address = "10.42.250.1";
          hostMac = "02:00:00:00:fa:01";
          deviceMac = "02:00:00:00:fa:02";
        };
        systemd.services.usb-gadget.enable = false;

        # Gaming belongs to Korri. Steam is the one exception: Korri has no
        # Steam provider for x86_64.
        programs.steam.enable = true;
        nixpkgs.config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "steam"
            "steam-unwrapped"
            "steam-run"
          ];

        # Nobody works at this machine, so it carries no coding agent and
        # needs no AI gateway key.
        mountainous.appProfiles.pi.enable = false;

        # The machine was installed at 24.11. Korri's product sets 25.11.
        system.stateVersion = lib.mkForce "24.11";

        assertions = [
          {
            assertion = !(options ? disko);
            message = "aka: disko must never manage these disks. Remove it.";
          }
          {
            assertion = !config.systemd.targets.hibernate.enable && !config.systemd.targets.sleep.enable;
            message = "aka must not sleep or hibernate.";
          }
          {
            assertion = config.users.users.simon.uid == 1000 && !(config.users.users ? simonwjackson);
            message = "aka: simon is the only human account, with the old account's UID 1000.";
          }
        ];
      };
  };
}
