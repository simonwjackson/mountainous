{lib, ...}: {
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "zao";
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  mountainous = {
    presets.core = {
      enable = true;
      # TODO: remove before committing
      passwordHash = "$6$bGAB/OPwyzz7AKMK$5MV3Ak8izkYQDdRFmzt8R/8joddHc1fHXMK9qBbwM3UQRlRMwX5JtsyGpq5tnU7BX7K8ibq1HshEp2kvKv/aA1";
    };
    presets.workstation.enable = true;
    presets.server.enable = true;

    features.disk-array = {
      enable = true;
      # NOTE: The original config had 6 disks (iceberg00–05). Only 5 are
      # physically present as of 2026-04-05. The missing 6th disk was:
      #   id = "05"; device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGK9H0C-0:0"
      # It appeared in the old fstab but is not connected. Investigate whether
      # this disk still exists and should be added back to the pool.
      pools.tank0 = {
        disks = [
          {
            id = "00";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGKDA3C-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
          {
            id = "01";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VRJVWS3K-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
          {
            id = "02";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH3KRAG-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
          }
          {
            id = "03";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH13XMG-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
          }
          {
            id = "04";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_WD-CA081PBK-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
        ];

        cache.enable = true;

        mergerfs.dataDisks = ["00" "01" "04"];

        snapraid = {
          enable = true;
          dataDisks = ["00" "01" "04"];
          parityDisks = ["02" "03"];
        };

        usb = {
          disableAutosuspend = true;
          udevRules = [{vendor = "152d"; product = "0578";}];
        };
      };
    };

    features.device = {
      role = "portable";
      capabilities = {
        battery = true;
        formFactor = "laptop";
        touchscreen = false;
      };
    };
  };

  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
  ];

  system.stateVersion = "26.05";
}
