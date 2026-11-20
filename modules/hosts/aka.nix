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
      # Only Korri's server part: other devices bring the UI (korri ADR 0051).
      "korri-server"
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

        # The RX 7900's GC 11.0.0 (Navi 31) command-processor and MES
        # firmware from linux-firmware 20261019. Korri's nixpkgs ships
        # 20260916, which carries the GC 11.0.0 update that upstream reverted
        # two days later because it hangs the gfx ring in games
        # (linux-firmware 0a5565a4 and 9a7c283f, drm/amd#5711). On aka that
        # firmware hung the GPU under sunshine, shadPS4 and a GR2 port, and
        # MES then failed the queue reset, so each hang became a MODE1 reset
        # that lost VRAM for every session. 20261019 restores the 20260622
        # blobs. Only these five files change; everything else stays 20260916.
        gc11Firmware =
          let
            rev = "a4ce85e98a33fa1021c31d1887fc2dffed27e8dd"; # tag 20261019
            blob =
              name: hash:
              pkgs.fetchurl {
                url = "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/${rev}/amdgpu/${name}";
                inherit hash;
              };
            blobs = {
              "gc_11_0_0_me.bin" = "sha256-8nTcRFKddJsan6BidrjzKilooWroAYlr0RxTsjTMjhs=";
              "gc_11_0_0_mec.bin" = "sha256-2lkD0NEVZvTICKi56PerugqGlZYQ5fWY1Qjr0V0dPug=";
              "gc_11_0_0_mes1.bin" = "sha256-h0DZo7zc0L4PBILsfbeQB6EaboNXqpV2cyhssT342sA=";
              "gc_11_0_0_mes_2.bin" = "sha256-0p6vC5mvg3hfnYz+POeR8PsepCay9fCnVqUNPtsGyVc=";
              "gc_11_0_0_pfp.bin" = "sha256-1Xs0or1FwclEg03xZlVhL1s+NPWWScqxOMwwlYkfYbM=";
            };
          in
          pkgs.runCommand "amdgpu-gc-11.0.0-firmware-20261019" { } (
            ''
              mkdir -p $out/lib/firmware/amdgpu
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: hash: ''
                cp ${blob name hash} $out/lib/firmware/amdgpu/${name}
              '') blobs
            )
          );
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
        # install, as a backup of the boot files only. Root is RAID0 across
        # both drives, so losing either drive still loses the system.
        # Every command has a store path: nixos-rebuild runs the switch in a
        # systemd-run unit whose PATH has no coreutils, and a bare mkdir
        # failed the bootloader install there on 2026-11-09.
        boot.loader.systemd-boot.extraInstallCommands = ''
          ${pkgs.coreutils}/bin/mkdir -p /boot/efi-backup
          if ! ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
            ${pkgs.util-linux}/bin/mount /dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup || true
          fi
          # Copy only onto a mounted ESP. Without the mount, rsync would copy
          # /boot into itself and fill it.
          if ${pkgs.util-linux}/bin/mountpoint -q /boot/efi-backup; then
            ${pkgs.rsync}/bin/rsync -a --delete-before --exclude='/efi-backup' /boot/ /boot/efi-backup/
            ${pkgs.util-linux}/bin/umount /boot/efi-backup || true
          else
            echo "efi-backup: spare ESP not mounted; skipped the copy" >&2
          fi
        '';

        boot.initrd.kernelModules = [ "amdgpu" ];
        # First in the list wins a name collision (hardware.firmware). The
        # initrd copies its amdgpu firmware from the same list.
        hardware.firmware = lib.mkBefore [ gc11Firmware ];
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
          mainDisplay = "HDMI-A-1";
          displays = [
            {
              name = "HDMI-A-1";
              mode = "1920x1080@60Hz";
              x = 0;
              y = 0;
              touch = null;
              # Nobody watches the dummy plug; it exists for Sunshine's
              # capture, so Korri must never idle it off.
              unwatched = true;
            }
          ];
        };

        # The owner's personal plugin publisher, as on the Odin and the Mini V2
        # (korri nix/devices/odin2portal/owner-publisher.nix): packages arrive
        # signed by this key into a root-only file cache on aka; nothing is
        # published. First case: @simonwjackson:savagewind.
        services.korri.pluginHost.publishers."@simonwjackson" = {
          publicKey = "simonwjackson-plugins-1:4SchQgTMNU3syZ2ZzN/cJXPMigc/PIt+EaqHAStgJs8=";
          cacheUrl = "file:///var/lib/korri-private-cache/cache";
        };

        # amd-pstate-epp offers only performance and powersave. powersave is
        # its load-following mode, the role schedutil has on other devices.
        # korri-limits refuses to start on a governor the CPU lacks.
        services.korri.clockGovernor.cpuGovernor = "powersave";

        # simon holds UID 1000, Korri's default for its runtime account
        # (see ibuki.nix). 56774 matches ibuki.
        services.korriProduct.runtimeAccount.uid = 56774;

        # Hookshot's game runner, as the korri account, shares game memory
        # with the GPU through /dev/udmabuf. Without read/write there the
        # game runs at 16-20 fps instead of about 40. systemd gives the node
        # to root:kvm 0660, and libcamera's uaccess tag reaches seat sessions
        # only, which a service account never has. The kvm group would also
        # open /dev/kvm, so grant this one account an ACL on this one node.
        # udev resets the node's permissions on each event and then runs
        # RUN, so the ACL returns after every add and every re-trigger.
        services.udev.extraRules = ''
          ACTION!="remove", SUBSYSTEM=="misc", KERNEL=="udmabuf", RUN+="${pkgs.acl}/bin/setfacl -m u:${config.users.users.korri.name}:rw /dev/%k"
        '';

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

        # Korri's device-cache policy forces max-jobs to 0, meant for handheld
        # devices. Aka is a fleet builder (fleet.builders.aka above), so it must
        # build what it is sent. Priority 49 beats that module's mkForce (50).
        # Its forwarding stays off (builders = "", distributedBuilds = false).
        nix.settings.max-jobs = lib.mkOverride 49 "auto";

        # Gaming belongs to Korri, Steam included: @korri:steam runs on x86_64
        # since korri-os/plugins 207796f, with the library in the person's
        # Korri Steam home.

        # Nobody works at this machine, so it carries no coding agent and
        # needs no AI gateway key.
        mountainous.appProfiles.pi.enable = false;

        # The machine was installed at 24.11. Korri's product sets 25.11.
        system.stateVersion = lib.mkForce "24.11";

        assertions = [
          {
            assertion = lib.versionOlder pkgs.linux-firmware.version "20261019";
            message = "aka: nixpkgs now ships linux-firmware ${pkgs.linux-firmware.version}, which has the fixed GC 11.0.0 firmware. Remove gc11Firmware.";
          }
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
