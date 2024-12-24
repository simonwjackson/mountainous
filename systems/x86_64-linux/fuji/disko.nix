# TODO: Yubi key
# https://haseebmajid.dev/posts/2024-07-30-how-i-setup-btrfs-and-luks-on-nixos-using-disko/
{device}: {
  mountainous.impermanence = {
    enable = true;
    persistPath = "/tundra/permafrost";
  };

  boot = {
    supportedFilesystems = ["btrfs"];
    kernelModules = [
      "cryptd"
      # "aesni_intel"
      "dm_mod"
    ];
  };

  fileSystems = {
    "/".neededForBoot = true;
    "/tundra/igloo".neededForBoot = true;
    "/nix".neededForBoot = true;
    "/boot".neededForBoot = true;
    "/var/log".neededForBoot = true;
  };
  disko.devices = {
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "mode=755"
          "size=2G"
        ];
      };
    };

    disk = {
 

      main = {
        inherit device;

        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            mukluk = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };

            esp = {
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            frostbite = {
              size = "100%";
              content = {
                type = "luks";
                name = "frostbite";
                askPassword = true;
                extraOpenArgs = ["--allow-discards"];
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"];
                  subvolumes = {
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/var/log" = {
                      mountpoint = "/var/log";
                      mountOptions = ["compress=zstd" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/swap" = {
                      mountpoint = "/swap";
                      mountOptions = ["noatime" "discard=async" "space_cache=v2"];
                      swap.swapfile.size = "32G";
                    };

                    # Identity
                    "/tundra/igloo" = {
                      mountpoint = "/tundra/igloo";
                      mountOptions = [
                        "compress=zstd:3" # Higher compression ratio since config files compress well
                        "noatime" # Keep this, good for performance
                        "discard=async" # Keep this, good for SSD health
                        "space_cache=v2" # Keep this, good for performance
                        "autodefrag" # Help prevent fragmentation of small files
                        "nosuid" # Security: prevent setuid programs in home dir
                        "nodev" # Security: prevent device files in home dir
                      ];
                    };

                    # Persist
                    "/tundra/permafrost" = {
                      mountpoint = "/tundra/permafrost";
                      mountOptions = ["compress=zstd" "noatime" "discard=async" "space_cache=v2"];
                    };

                    # Snowscape
                    "/tundra/frostbite/snowscape" = {
                      mountpoint = "/tundra/frostbite/snowscape";
                      mountOptions = ["compress=zstd" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/code" = {
                      mountpoint = "/tundra/frostbite/snowscape/code";
                      mountOptions = ["compress=zstd:1" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/video" = {
                      mountpoint = "/tundra/frostbite/snowscape/video";
                      mountOptions = ["nodatacow" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/music" = {
                      mountpoint = "/tundra/frostbite/snowscape/music";
                      mountOptions = ["compress=zstd:1" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/audiobooks" = {
                      mountpoint = "/tundra/frostbite/snowscape/audiobooks";
                      mountOptions = ["compress=zstd:1" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/photos" = {
                      mountpoint = "/tundra/frostbite/snowscape/photos";
                      mountOptions = ["compress=zstd:3" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/notes" = {
                      mountpoint = "/tundra/frostbite/snowscape/notes";
                      mountOptions = ["compress=zstd:3" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/gaming" = {
                      mountpoint = "/tundra/frostbite/snowscape/gaming";
                      mountOptions = ["compress=zstd" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/gaming/games" = {
                      mountpoint = "/tundra/frostbite/snowscape/gaming/games";
                      mountOptions = ["nodatacow" "noatime" "discard=async" "space_cache=v2"];
                    };
                    "/tundra/frostbite/snowscape/gaming/profiles" = {
                      mountpoint = "/tundra/frostbite/snowscape/gaming/profiles";
                      mountOptions = ["compress=zstd:1" "noatime" "discard=async" "space_cache=v2"];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
