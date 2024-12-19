# TODO: Yubi key
# https://haseebmajid.dev/posts/2024-07-30-how-i-setup-btrfs-and-luks-on-nixos-using-disko/
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # extraOpenArgs = [
                #   "--allow-discards"
                #   "--perf-no_read_workqueue"
                #   "--perf-no_write_workqueue"
                # ];
                # settings = {crypttabExtraOpts = ["fido2-device=auto" "token-timeout=10"];};
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"];
                  # extraArgs = ["-L" "nixos" "-f"];
                  subvolumes = {
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    # "/log" = {
                    #   mountpoint = "/var/log";
                    #   mountOptions = ["subvol=log" "compress=zstd" "noatime"];
                    # };
                    "/persist/system" = {
                      mountpoint = "/persist";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                  };
                };
              };
            };
          };
        };
      };
      sleet0 = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "f2fs";
                mountpoint = "/avalanche/disks/sleet/0/00";
                mountOptions = ["noatime"];
              };
            };
          };
        };
      };
    };
  };
}
