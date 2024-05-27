{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  age,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./services/films.nix
    ./services/paperless-ngx.nix
    ./services/series.nix
    ./services/tandoor.nix
    ./services/indexers.nix
    ./services/torrents.nix
    ./services/usenet.nix
    ./services/vpn.nix
    ./services/youtube.nix
  ];

  backpacker = {
    performance.enable = true;
    profiles.laptop.enable = true;
    hardware.cpu.type = "intel";
    networking.core.names = [
      {
        name = "eth-primary";
        mac = "70:85:c2:c3:ff:09";
      }
      {
        name = "eth-secondary";
        mac = "00:e0:4c:68:01:39";
      }
    ];
  };

  services.gamerack = {
    enable = true;
    database = "/glacier/snowscape/gaming/profiles/simonwjackson/games.yaml";
    environmentFiles = [
      config.age.secrets.game-collection-sync.path
    ];
    environment = {
      STEAM_ID = "76561198041190539";
      MOBY_USERNAME = "simonwjackson";
      MOBY_COLLECTION_ID = "333655";
      MOBY_COOKIE_FILE = "/tmp/mobygames-cookie.txt";
    };
  };

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/e7992d4c-23f6-453e-99b8-b68a717a6156";
  #   fsType = "btrfs";
  #   options = ["subvol=root"];
  # };
  #
  # fileSystems."/home" = {
  #   device = "/dev/disk/by-uuid/e7992d4c-23f6-453e-99b8-b68a717a6156";
  #   fsType = "btrfs";
  #   options = ["subvol=home"];
  # };
  #
  # fileSystems."/nix" = {
  #   device = "/dev/disk/by-uuid/e7992d4c-23f6-453e-99b8-b68a717a6156";
  #   fsType = "btrfs";
  #   options = ["subvol=nix"];
  # };

  disko.devices = {
    disk = {
      iceberg = {
        type = "disk";
        device = "/dev/disk/by-label/iceberg";
        content = {
          type = "filesystem";
          format = "btrfs";
          mountOptions = ["compress=zstd" "noatime" "autodefrag" "space_cache=v2"];
          mountpoint = "/glacier/iceberg";
        };
      };
      nvme = {
        type = "disk";
        device = "/dev/disk/by-uuid/e7992d4c-23f6-453e-99b8-b68a717a6156";
        content = {
          type = "btrfs";
          subvolumes = {
            "/root" = {
              mountpoint = "/";
              mountOptions = ["compress=zstd"];
            };
            "/home" = {
              mountpoint = "/home";
              mountOptions = ["compress=zstd"];
            };
            "/nix" = {
              mountpoint = "/nix";
              mountOptions = ["compress=zstd" "noatime"];
            };
          };
        };
      };
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A777-1B40";
    fsType = "vfat";
  };

  services.audiobookshelf = {
    user = "simonwjackson";
    enable = true;
    port = 8000;
    host = "0.0.0.0";
  };

  fileSystems."/glacier/snowscape/services/audiobookshelf" = {
    depends = [
      "/glacier/snowscape"
    ];
    device = "/var/lib/audiobookshelf";
    fsType = "none";
    options = [
      "bind"
      "ro"
    ];
  };

  systemd.services.mountSnowscape = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape
      ${pkgs.util-linux}/bin/mountpoint -q /glacier/snowscape || ${pkgs.mount}/bin/mount -t bcachefs /dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0RA01126_1-part1:/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650_1-part1:/dev/disk/by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C-part1:/dev/disk/by-id/ata-WDC_WD80EFBX-68AZZN0_VRJVWS3K-part1:/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH3KRAG-part1:/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH13XMG-part1:/dev/disk/by-partuuid/4c63c6a0-ca41-e64f-bf66-1b8ea170e5f9:/dev/disk/by-partuuid/a65978da-998d-db4c-aaef-d7e3321d11c3:/dev/disk/by-partuuid/99bd5d36-9353-4754-837b-008e0d92fe28:/dev/disk/by-partuuid/1627228d-5821-3a40-8e29-0d48928b5852 /glacier/snowscape
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];
  boot.supportedFilesystems = ["bcachefs"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.jellyfin = {
    enable = true;
    user = "simonwjackson";
    group = "users";
  };

  systemd.services.ensureNfsRoot = {
    script = ''
      install -d -o nobody -g nogroup -m 770 /export
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  fileSystems."/export/snowscape" = {
    device = "/glacier/snowscape";
    options = ["bind"];
  };

  fileSystems."/home/simonwjackson/code" = {
    device = "/glacier/snowscape/code";
    options = ["bind"];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export		192.18.0.0/16(rw,fsid=0,no_subtree_check,crossmnt)	100.0.0.0/8(rw,fsid=0,no_subtree_check,crossmnt)
      /export/snowscape	192.18.0.0/16(fsid=1,insecure,rw,sync,no_subtree_check)	100.0.0.0/8(fsid=1,insecure,rw,sync,no_subtree_check)
    '';
  };

  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 100. 192.18. 10.147.19. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
      acl allow execute always = True
    '';
    shares = {
      snowscape = {
        path = "/glacier/snowscape";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "simonwjackson";
        "force group" = "users";
      };
    };
  };

  services.borgbackup.jobs = {
    taskwarrior = {
      paths = "/home/simonwjackson/.local/share/task";
      repo = "/glacier/iceberg/permafrost/taskwarrior";
      encryption.mode = "none";
      compression = "zstd,22";
      startAt = "hourly";
      prune = {
        keep = {
          within = "7d";
        };
      };
    };

    gaming-profiles = {
      paths = "/glacier/snowscape/gaming/profiles";
      repo = "/glacier/iceberg/permafrost/gaming/profiles";
      encryption.mode = "none";
      compression = "zstd,22";
      startAt = "daily"; # every day
      exclude = [];
      prune = {
        keep = {
          within = "30d";
        };
      };
    };

    photos = {
      paths = "/glacier/snowscape/photos";
      repo = "/glacier/iceberg/permafrost/photos";
      encryption.mode = "none";
      compression = "zstd,22";
      startAt = "daily"; # every day
    };

    notes = {
      paths = "/glacier/snowscape/documents/notes";
      repo = "/glacier/iceberg/permafrost/notes";
      encryption.mode = "none";
      startAt = "daily"; # every day
      prune = {
        keep = {
          within = "30d";
        };
      };
    };
  };

  services.syncthing = {
    enable = true;
    key = config.age.secrets.unzen-syncthing-key.path;
    cert = config.age.secrets.unzen-syncthing-cert.path;
  };

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [brlaser];

  # Enable automatic discovery of the printer from other Linux systems with avahi running. services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.printing.browsing = true;
  services.printing.listenAddresses = ["*:631"]; # Not 100% sure this is needed and you might want to restrict to the local network
  services.printing.allowFrom = ["all"]; # this gives access to anyone on the interface you might want to limit it see the official documentation
  services.printing.defaultShared = true; # If you want

  system.stateVersion = "23.05"; # Did you read the comment?
}
