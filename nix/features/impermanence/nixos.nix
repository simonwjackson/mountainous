{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkMerge mkForce;

  cfg = config.mountainous.impermanence;
  device = config.mountainous.device;
  gaming = config.mountainous.gaming;

  # Device-based detection
  isPortable = device.isPortable or false;
  hasBattery = device.capabilities.battery or false;
  hasBluetooth = config.hardware.bluetooth.enable or false;

  # Common directories ALL systems need
  coreDirs = [
    "/var/lib/systemd/coredump"
    "/var/lib/nixos"
    "/var/lib/tailscale"
    {
      directory = "/home/${cfg.user}";
      user = cfg.user;
      group = "users";
      mode = "0700";
    }
    {
      directory = "/nix/var/nix/profiles/per-user/${cfg.user}";
      user = cfg.user;
      group = "users";
      mode = "0755";
    }
  ];

  # Device-auto-detected directories
  autoDirs =
    []
    # Portable devices or battery-equipped need NetworkManager
    ++ lib.optionals (cfg.autoDetect.fromDevice && (isPortable || hasBattery)) [
      "/etc/NetworkManager/system-connections"
    ]
    # Gaming or bluetooth-enabled systems need bluetooth state
    ++ lib.optionals (cfg.autoDetect.fromDevice && (gaming.enable or hasBluetooth)) [
      "/var/lib/bluetooth"
    ];

  # All persistence directories
  allDirs = coreDirs ++ autoDirs ++ cfg.extraDirectories;

  # Core files ALL systems need
  coreFiles = [
    "/etc/machine-id"
  ];

  # All persistence files
  allFiles = coreFiles ++ cfg.extraFiles;
in {
  options.mountainous.impermanence = import ./options.nix {inherit lib;};

  config = mkIf cfg.enable (mkMerge [
    # Base impermanence configuration
    {
      # Enable FUSE for user bind mounts
      programs.fuse.userAllowOther = true;

      # Root filesystem (tmpfs)
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
        options = ["defaults" "size=${cfg.rootSize}" "mode=755"];
      };

      # Configure persistence using impermanence module
      environment.persistence."${cfg.persistPath}" = {
        hideMounts = true;
        directories = allDirs;
        files = allFiles;
      };

      # SSH host keys in persistent storage
      # Critical: these MUST be in persistent storage for agenix and remote access
      services.openssh.hostKeys = [
        {
          path = "${cfg.persistPath}/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
        {
          path = "${cfg.persistPath}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      # Agenix identity paths
      # Point to persistent SSH keys for secret decryption
      age.identityPaths = [
        "${cfg.persistPath}/etc/ssh/ssh_host_rsa_key"
      ];

      # Fix ownership of persistent directories on boot
      # Workaround for impermanence bug where parent directories are created with root ownership
      # See: https://github.com/nix-community/impermanence/issues/74
      systemd.tmpfiles.settings."10-persistent-ownership" = {
        "${cfg.persistPath}/home/${cfg.user}".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        "${cfg.persistPath}/nix/var/nix/profiles/per-user/${cfg.user}".d = {
          user = cfg.user;
          group = "users";
          mode = "0755";
        };
      };
    }

    # Persistent storage mount (if device specified)
    (mkIf (cfg.persistDevice != null) {
      fileSystems."${cfg.persistPath}" = {
        device = cfg.persistDevice;
        fsType = cfg.persistFsType;
        options = cfg.persistOptions;
        neededForBoot = true;
      };
    })

    # Persist Nix store (optional, for faster rebuilds)
    (mkIf cfg.persistNixStore {
      environment.persistence."${cfg.persistPath}".directories = mkForce (
        allDirs
        ++ [
          "/nix"
        ]
      );
    })

    # Persist logs (optional, for debugging)
    (mkIf cfg.persistLogs {
      environment.persistence."${cfg.persistPath}".directories = mkForce (
        allDirs
        ++ [
          "/var/log"
        ]
      );
    })
  ]);
}
