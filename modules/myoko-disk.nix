# The Zenbook stores platform firmware before the operating-system space on its
# only NVMe disk. This layer describes the installed filesystems but does not
# partition or format the disk. scripts/install-myoko owns that guarded,
# one-machine operation.
{
  nixos.modules.myoko-disk = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Blank tty1 after five idle minutes. Hyprland handles DPMS in graphical
    # sessions.
    systemd.services.myoko-console-blank = {
      description = "Enable Myoko text-console blanking after root unlock";
      wantedBy = ["multi-user.target"];
      before = ["greetd.service"];
      path = [pkgs.util-linux];
      script = "setterm --blank 5";
      serviceConfig = {
        Type = "oneshot";
        StandardInput = "tty";
        StandardOutput = "tty";
        TTYPath = "/dev/tty1";
      };
    };

    boot.loader.efi.efiSysMountPoint = "/efi";
    boot.loader.systemd-boot = {
      enable = true;
      xbootldrMountPoint = "/boot";
      configurationLimit = 3;
    };

    # NVMe and PCIe are built in, but the PCIe PHY and its TCSR clock are
    # modules. Include them before mounting root; the RAM-root USB probe
    # hides their absence by loading them from its full store in stage 2.
    # Keep the initrd limited to drivers present in the trimmed kernel.
    boot.initrd.availableKernelModules = lib.mkForce [
      "tcsrcc-glymur"
      "phy-qcom-qmp-pcie"
      "btrfs"
    ];
    boot.initrd.kernelModules = lib.mkAfter [
      "tcsrcc-glymur"
      "phy-qcom-qmp-pcie"
      "btrfs"
    ];

    # Firmware advertises TPM devices that Linux cannot expose on this
    # machine. Do not wait for them during either initrd or normal boot.
    boot.initrd.systemd.tpm2.enable = false;
    systemd.tpm2.enable = false;

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-partuuid/32b9d8ba-5c9a-4072-a6e6-44e1109701b7";
        fsType = "btrfs";
        options = [
          "subvol=@"
          "compress=zstd:1"
          "noatime"
        ];
      };

      "/home" = {
        device = "/dev/disk/by-partuuid/32b9d8ba-5c9a-4072-a6e6-44e1109701b7";
        fsType = "btrfs";
        options = [
          "subvol=@home"
          "compress=zstd:1"
          "noatime"
        ];
      };

      "/nix" = {
        device = "/dev/disk/by-partuuid/32b9d8ba-5c9a-4072-a6e6-44e1109701b7";
        fsType = "btrfs";
        options = [
          "subvol=@nix"
          "compress=zstd:1"
          "noatime"
        ];
      };

      # Partition 12 is the factory ESP. Its GPT identity is part of the
      # verified platform layout and remains unchanged by installation.
      "/efi" = {
        device = "/dev/disk/by-partuuid/510df826-ed9a-4adb-9f23-fb677f3e29b3";
        fsType = "vfat";
        options = ["umask=0077"];
      };

      # Partition 13 replaces the Microsoft reserved partition and gives
      # kernels and initrds room without filling the 450 MiB factory ESP.
      "/boot" = {
        device = "/dev/disk/by-partlabel/XBOOTLDR";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    assertions = [
      {
        assertion = lib.hasPrefix "/dev/disk/by-partuuid/" config.fileSystems."/efi".device;
        message = "myoko must mount the verified factory ESP by PARTUUID";
      }
    ];
  };
}
