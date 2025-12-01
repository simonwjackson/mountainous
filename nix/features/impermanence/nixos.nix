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
  # Note: /var/lib/tailscale is managed by mountainous.tailscale module
  coreDirs = [
    "/var/lib/systemd/coredump"
    "/var/lib/nixos"
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

  # Disko subvolume generation
  diskoSubvolumes =
    lib.optionalAttrs cfg.persistNixStore {
      "@nix" = {
        mountpoint = "/nix";
        mountOptions = cfg.disko.mountOptions;
      };
    }
    // {
      "@permafrost" = {
        mountpoint = cfg.persistPath;
        mountOptions = cfg.disko.mountOptions;
      };
    }
    // lib.optionalAttrs cfg.persistLogs {
      "@log" = {
        mountpoint = "/var/log";
        mountOptions = cfg.disko.mountOptions;
      };
    };
in {
  options.mountainous.impermanence = import ./options.nix {inherit lib;};

  config = mkIf cfg.enable (mkMerge [
    # Disko subvolume contribution
    (mkIf cfg.disko.enable {
      disko.devices.disk.${cfg.disko.diskName}.content.partitions.${cfg.disko.partitionName}.content.subvolumes =
        lib.mkDefault diskoSubvolumes;
    })

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
      # Only RSA is needed - agenix uses RSA, and RSA 4096 is sufficient for SSH
      services.openssh.hostKeys = [
        {
          path = "${cfg.persistPath}/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
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
      # Also ensures XDG directories exist with correct ownership before services start
      systemd.tmpfiles.settings."10-persistent-ownership" = {
        "${cfg.persistPath}/home/${cfg.user}".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        # XDG Base Directory - needed by hyprland, sddm, dconf, and many other services
        "${cfg.persistPath}/home/${cfg.user}/.local".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        "${cfg.persistPath}/home/${cfg.user}/.local/share".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        "${cfg.persistPath}/home/${cfg.user}/.local/state".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        "${cfg.persistPath}/home/${cfg.user}/.config".d = {
          user = cfg.user;
          group = "users";
          mode = "0700";
        };
        "${cfg.persistPath}/home/${cfg.user}/.cache".d = {
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
      };
    })

    # Always ensure persistPath is available at boot (even when disko manages the mount)
    {
      fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;
    }

    # Persist Nix store (when not using disko subvolume)
    # NOTE: /var/log is handled by disko @log subvolume when persistLogs=true,
    # so we don't add it to impermanence (that would create conflicting mounts)
    (mkIf (cfg.persistNixStore && !cfg.disko.enable) {
      environment.persistence."${cfg.persistPath}".directories = mkForce (
        allDirs
        ++ ["/nix"]
      );
    })
  ]);
}
