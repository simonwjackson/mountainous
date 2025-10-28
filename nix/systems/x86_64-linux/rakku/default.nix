{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    ./disko.nix
  ];

  # UEFI boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Hardware modules for rakku (Intel Celeron J1900)
  boot.initrd.availableKernelModules = [
    "ahci" # SATA controller
    "xhci_pci" # USB 3.0
    "usb_storage"
    "sd_mod"
  ];

  boot.kernelModules = ["igb"]; # Intel I211 Gigabit NIC

  # Enable base profile
  mountainous.profiles.base.enable = true;

  # Disable impermanence module (configure manually below)
  mountainous = {
    impermanence.enable = lib.mkForce false;
  };

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Mark persistent storage as needed early in boot
  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Local impermanence configuration for rakku (home-assistant box)
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  # Fix ownership of persistent directories on boot
  # Workaround for impermanence bug where parent directories are created with root ownership
  # See: https://github.com/nix-community/impermanence/issues/74
  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/home/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/nix/var/nix/profiles/per-user/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    # SSH host keys in persistent storage
    # Keys will need to exist in /tundra/permafrost/etc/ssh/ before first boot
    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  # Basic firewall configuration
  # Add Home Assistant ports (8123) as needed
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };

  system.stateVersion = "24.11";
}
