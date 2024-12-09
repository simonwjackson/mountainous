{
  inputs,
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  mountainous = {
    hardware = {
      cpu.type = "intel";
    };
    performance = enabled;
    networking.core.names = [
      {
        name = "primary";
        mac = "68:fe:f7:11:c1:fd";
      }
    ];
    syncthing = {
      enable = false;
      # key = config.age.secrets.fiji-syncthing-key.path;
      # cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  /*
  ###############################################
  # DESTRUCTIVE OPERATIONS - CANNOT BE UNDONE!  #
  ###############################################

  # 1. Destroy existing partition tables
  sgdisk -Z /dev/sdX  # Replace X with your first disk letter
  sgdisk -Z /dev/sdY  # Replace Y with your second disk letter

  # 2. Create new partitions
  sgdisk -n 1:0:0 -t 1:BF01 /dev/sdX
  sgdisk -n 1:0:0 -t 1:BF01 /dev/sdY

  # 3. Create ZFS pool
  zpool create iceberg mirror /dev/sdX1 /dev/sdY1
  */

  # ZFS services configuration
  services.zfs = {
    zed.settings = {
      ZED_DEBUG_LOG = "/var/log/zed.log";
      ZED_EMAIL_ADDR = "haku@simonwjackson.io";
      ZED_EMAIL_PROG = "mail";
      ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
    };
    trim.enable = false;
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
      frequent = 8;
      hourly = 24;
      daily = 14;
      weekly = 8;
      monthly = 12;
    };
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };

  systemd.services.zfs-setup = {
    description = "Configure ZFS dataset properties";
    wantedBy = ["multi-user.target"];
    after = ["zfs.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "zfs-setup" ''
        # Pool-level properties
        ${pkgs.zfs}/bin/zfs set compression=lz4 iceberg || true
        ${pkgs.zfs}/bin/zfs set atime=off iceberg || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg || true

        # Photos dataset
        ${pkgs.zfs}/bin/zfs create -p iceberg/photos 2>/dev/null || true
        ${pkgs.zfs}/bin/zfs set compression=zstd iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set dedup=off iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set recordsize=128K iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set mountpoint=/avalanche/pools/iceberg/photos iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg/photos || true
        ${pkgs.zfs}/bin/zfs set aclinherit=passthrough iceberg/photos || true

        # Music dataset
        ${pkgs.zfs}/bin/zfs create -p iceberg/music 2>/dev/null || true
        ${pkgs.zfs}/bin/zfs set compression=lz4 iceberg/music || true
        ${pkgs.zfs}/bin/zfs set dedup=off iceberg/music || true
        ${pkgs.zfs}/bin/zfs set recordsize=1M iceberg/music || true
        ${pkgs.zfs}/bin/zfs set mountpoint=/avalanche/pools/iceberg/music iceberg/music || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg/music || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg/music || true
        ${pkgs.zfs}/bin/zfs set aclinherit=passthrough iceberg/music || true

        # Var dataset
        ${pkgs.zfs}/bin/zfs create -p iceberg/var 2>/dev/null || true
        ${pkgs.zfs}/bin/zfs set compression=zstd iceberg/var || true
        ${pkgs.zfs}/bin/zfs set dedup=off iceberg/var || true
        ${pkgs.zfs}/bin/zfs set recordsize=128K iceberg/var || true
        ${pkgs.zfs}/bin/zfs set mountpoint=/avalanche/pools/iceberg/var iceberg/var || true
        ${pkgs.zfs}/bin/zfs set acltype=posixacl iceberg/var || true
        ${pkgs.zfs}/bin/zfs set xattr=sa iceberg/var || true
        ${pkgs.zfs}/bin/zfs set aclinherit=passthrough iceberg/var || true
      '';
    };
  };
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.extraPools = ["iceberg"];
  networking.hostId = "cd64761c";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/e0301dfa-9f5a-4342-a1ae-8864536430ee";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3411-11CB";
    fsType = "vfat";
  };

  system.stateVersion = "22.11"; # Did you read the comment?

  ######################################

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "eno1";
    };

    useHostResolvConf = false;
    resolvconf.enable = false;
  };

  containers = let
    tailscaleAuthFile = config.age.secrets."heidi-tailscale".path;
    tailscaleMagicDns = "paradise-mimosa.ts.net";
    hostAddress = "192.168.123.1";
  in {
    photos = let
    in {
      inherit hostAddress;
      localAddress = "192.168.123.10";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleAuthFile}".hostPath = tailscaleAuthFile;
        "/photos" = {
          hostPath = "/avalanche/pools/iceberg/photos";
          isReadOnly = false;
        };
        "/var/lib/immich" = {
          hostPath = "/avalanche/pools/iceberg/var/lib/immich";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        boot.kernel.sysctl = {
          "net.ipv6.conf.all.disable_ipv6" = 1;
          "net.ipv6.conf.default.disable_ipv6" = 1;
        };

        networking = {
          useHostResolvConf = false;
          resolvconf.enable = false;
          nameservers = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
          extraConfig = ''
            DNSStubListener=yes
            DNS=1.1.1.1 8.8.8.8
          '';
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleAuthFile;
              serve = 2283;
            };
          };
        };

        systemd.services.immich = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.immich = {
          enable = true;
          database.user = "media";
          database.name = "media";
          user = "media";
          group = "media";
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
            isSystemUser = true;
            hashedPassword = "!";
          };
        };
      };
    };
  };

  services.samba = {
    enable = true;
    securityType = "user";
    settings = {
      global = {
        workgroup = "HEIDI";
        "server string" = "Heidi";
        "server role" = "standalone server";
        "map to guest" = "bad user";
        "guest account" = "media";
      };
    };
    shares = {
      photos = {
        path = "/avalanche/pools/iceberg/photos";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "2775";
        "force user" = "media";
        "force group" = "media";
      };
    };
  };
  # Create Samba users
  services.samba.enableNmbd = true; # NetBIOS name server
  services.samba.enableWinbindd = false;

  # networking.firewall.allowedTCPPorts = [445 139];
  # networking.firewall.allowedUDPPorts = [137 138];
}
