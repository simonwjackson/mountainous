# GPD Pocket 1 - Disko configuration
#
# eMMC layout optimized for NixOS with impermanence
# Target: 116.5GB eMMC (DJNB4R)
#
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "8G"; # Match RAM for hibernate
              content = {
                type = "swap";
                randomEncryption = false; # Need stable swap for hibernate
              };
            };
            nix = {
              size = "40G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
                mountOptions = ["noatime" "discard"];
              };
            };
            persist = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/tundra/permafrost";
                mountOptions = ["noatime" "discard"];
              };
            };
          };
        };
      };
    };
  };
}
