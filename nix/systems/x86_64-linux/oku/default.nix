{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    # Use LTS kernel (6.6.x) - newer kernels have i915 DSI panel timing bugs
    # See: https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/8992
    # See: https://bbs.archlinux.org/viewtopic.php?id=303555
    kernelPackages = pkgs.linuxPackages_6_6;

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "uas"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = ["i915"]; # Early KMS for Intel graphics
    };

    kernelModules = [
      "kvm-intel"
      "i915"
      "btusb"
      "hid_multitouch"
      # IIO sensors for rotation
      "hid_sensor_rotation"
      "hid_sensor_accel_3d"
      "hid_sensor_gyro_3d"
      "hid_sensor_als"
    ];

    extraModulePackages = [];

    kernelParams = [
      # Resume device for hibernation
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # i915 DSI panel workarounds for MateBook E
      # TEST B: Both PSR and FBC enabled (LTS kernel only)
      # "i915.enable_psr=0"
      # "i915.enable_fbc=0"
      # If still crashing, uncomment nomodeset (disables GPU acceleration):
      # "nomodeset"

      # Intel power management
      "intel_pstate=active"

      # Power management for tablet
      "mem_sleep_default=deep"

      # Verbose boot to see what's happening
      "loglevel=7"
    ];

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
    };

    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # Hardware configuration for Intel Core i5-1130G7 (Tiger Lake)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Intel Iris Xe Graphics
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # VAAPI for Tiger Lake+
        intel-vaapi-driver # Legacy VAAPI
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };
  };

  # Networking
  networking.hostName = "oku";
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;

  # Greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
      initial_session = {
        command = "Hyprland";
        user = "simonwjackson";
      };
    };
  };

  # Enable profiles
  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true;
    };

    sound.enable = true;

    # Auto-rotation for tablet
    # auto-rotate.enable = true;

    impermanence.enable = lib.mkForce false;
  };

  # Ephemeral root filesystem
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Impermanence configuration
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/bluetooth"
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

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # Tablet-specific services
  services = {
    # Power management (TLP for laptops/tablets)
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        # Battery charge thresholds (huawei-wmi)
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # WiFi power saving on battery
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
      };
    };

    acpid.enable = true;
    fwupd.enable = true;
    blueman.enable = true;

    # Touchscreen/stylus input
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = false;
        accelProfile = "adaptive";
      };
    };
  };

  # XDG portal paths for home-manager integration
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

  # Tablet utilities
  environment.systemPackages = with pkgs; [
    brightnessctl
    iio-sensor-proxy # For auto-rotation
  ];

  # Suspend-then-hibernate for battery life
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "suspend-then-hibernate";
    HandleLidSwitchExternalPower = lib.mkForce "suspend";
    HandlePowerKey = lib.mkForce "suspend-then-hibernate";
    HandlePowerKeyLongPress = lib.mkForce "poweroff";
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "input"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  system.stateVersion = "25.05";
}
