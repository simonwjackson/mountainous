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
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
      ];
      kernelModules = ["amdgpu"]; # Early KMS for AMD graphics
    };

    kernelModules = [
      "kvm-amd" # AMD virtualization
      "amdgpu" # AMD graphics driver
      "mt7921e" # MediaTek WiFi 6E
      "btusb" # Bluetooth
      "hid_multitouch" # Touchscreen
    ];

    extraModulePackages = [];

    # Kernel parameters optimized for AMD gaming handheld
    kernelParams = [
      # Resume device for hibernation (must match swap partition)
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # AMD GPU optimizations
      "amdgpu.ppfeaturemask=0xffffffff" # Enable all GPU power features
      "amdgpu.gpu_recovery=1" # Enable GPU hang recovery
      "amdgpu.dc=1" # Display Core for better display
      "amdgpu.dpm=1" # Dynamic Power Management

      # AMD CPU power management
      "amd_pstate=active" # Active P-state driver for better power

      # Power management for handheld
      "mem_sleep_default=deep" # Deep sleep for better battery

      # NVMe power state fix - critical for AMD sleep/wake reliability
      # Prevents NVMe drive from entering problematic power states during suspend
      "nvme_core.default_ps_max_latency_us=0"

      # PCIe ASPM disabled - fixes MT7921e WiFi resume and AMD GPU hibernate issues
      "pcie_aspm=off"

      # Display - let amdgpu KMS auto-detect native resolution
      "fbcon=nodefer" # Earlier framebuffer initialization

      # Quiet boot
      "loglevel=4"
      "quiet"
      "splash"
    ];

    # systemd-boot (UEFI) - simpler than GRUB for single-boot systems
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Limit generations (save space on 512GB)
        editor = false; # Disable boot editor for security
      };
    };

    # Resume from hibernate
    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # Hardware configuration for AMD Ryzen 5 5560U (Zen 3) + Radeon Graphics
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    # Bluetooth configuration (MediaTek MT7921 integrated)
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Power on Bluetooth adapter on boot
      # Enable experimental features for better codec support (headphones, controllers)
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # AMD Radeon Graphics (Cezanne)
    graphics = {
      enable = true;
      enable32Bit = true; # Essential for gaming (32-bit games/libraries)
      extraPackages = with pkgs; [
        # AMD Vulkan drivers (RADV is enabled by default, amdvlk was deprecated)
        # Video acceleration
        libva
        libvdpau-va-gl
      ];
      # 32-bit drivers (RADV is enabled by default)
    };

    # Enable AMD GPU OpenCL support
    amdgpu.opencl.enable = true;
  };

  # Networking
  networking.hostName = "hotaka";
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false; # Disable WiFi powersave for gaming

  # Auto-login to Hyprland for gaming handheld experience
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

  # Enable profiles for gaming handheld
  mountainous = {
    profiles = {
      base.enable = true;
      gaming.enable = true; # Steam, gamemode, controllers, etc.
    };

    # Enable sound with PipeWire for gaming
    sound.enable = true;

    # Override base profile's impermanence - configure locally
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

  # Local impermanence configuration for hotaka (gaming handheld)
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/bluetooth" # Bluetooth pairings (controllers, headphones)
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

  # Handheld-specific services
  services = {
    # Handheld Daemon - provides AYANEO-specific support
    # Features: TDP control, controller support, LED control, power profiles
    # Note: AYANEO AIR has "partial" support - controller and some features work
    handheld-daemon = {
      enable = true;
      user = "simonwjackson"; # Run as main user for device access
    };

    # Enable thermald? No - AMD doesn't need it (Intel-specific)
    # thermald.enable = false;

    # Enable auto-cpufreq for dynamic gaming handheld power management
    # (Choose either TLP or auto-cpufreq, not both!)
    # auto-cpufreq is better for gaming workloads - automatically detects and boosts
    auto-cpufreq = {
      enable = true;
      settings = {
        # Charger profile - maximize performance for gaming on AC
        charger = {
          governor = "schedutil"; # Dynamic scheduling for best balance
          turbo = "auto"; # Allow turbo boost automatically
          scaling_min_freq = 400000; # 400 MHz minimum
          scaling_max_freq = 4062000; # 4.062 GHz maximum (full boost)
        };

        # Battery profile - balance performance and battery life
        battery = {
          governor = "powersave"; # Powersave for battery efficiency
          turbo = "auto"; # Still allow turbo for responsive gaming
          scaling_min_freq = 400000; # 400 MHz minimum
          scaling_max_freq = 2800000; # 2.8 GHz cap for better battery life
          energy_performance_preference = "balance_power";
        };
      };
    };

    # ACPI event handling (lid, power button)
    acpid.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # Blueman: Bluetooth manager GUI (for pairing controllers, headphones)
    blueman.enable = true;

    # libinput for touchscreen
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = false;
        tapping = true;
        disableWhileTyping = false; # Handheld - no traditional typing
        accelProfile = "adaptive";
      };
    };
  };

  # Gamemode for automatic performance switching
  programs.gamemode.enable = true;

  # Use mountainous Steam module for comprehensive Steam setup
  mountainous.steam.enable = true;

  # Additional Steam configuration
  programs.steam = {
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true; # Steam Deck-like UI
  };

  # XFS-specific settings and handheld utilities
  # XFS doesn't need special services, but ensure xfsprogs is available
  environment.systemPackages = with pkgs; [
    xfsprogs # XFS utilities (xfs_repair, xfs_info, etc.)
    handheld-daemon # HHD CLI tools (hhd command, device support)
  ];

  # Suspend-then-hibernate for better battery life
  # Suspend for quick resume, hibernate after timeout for zero drain
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandlePowerKey = "suspend-then-hibernate";
    HandlePowerKeyLongPress = "poweroff";
  };

  # Handheld power management
  # Use schedutil governor (better for dynamic gaming workloads than performance/powersave)
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  # Post-sleep fixes for WiFi and display (runs after BOTH suspend AND hibernate)
  # Using systemd sleep hook instead of powerManagement.resumeCommands to support hibernate
  # This approach avoids the issue of services starting during system activation
  environment.etc."systemd/system-sleep/resume-fixes" = {
    source = pkgs.writeShellScript "resume-fixes" ''
      #!/bin/sh
      # systemd-sleep hook: called before sleep ($1=pre) and after resume ($1=post)
      # $2 contains the sleep type: suspend, hibernate, hybrid-sleep, suspend-then-hibernate

      # Only run after resume, not before sleep
      if [ "$1" != "post" ]; then
        exit 0
      fi

      # Reload MediaTek WiFi module to fix resume issues
      # First, find and bring down the WiFi interface to release the module
      WIFI_INTERFACE=$(${pkgs.iproute2}/bin/ip link show | ${pkgs.gnugrep}/bin/grep -oP '^\d+: \K(wl[^:]+)' | head -n1)

      if [ -n "$WIFI_INTERFACE" ]; then
        echo "Bringing down WiFi interface: $WIFI_INTERFACE"
        ${pkgs.iproute2}/bin/ip link set "$WIFI_INTERFACE" down
        sleep 1
      fi

      # Now unload modules in reverse dependency order
      # mt7921e depends on mt7921_common, which depends on mt792x_lib
      ${pkgs.kmod}/bin/modprobe -r mt7921e
      ${pkgs.kmod}/bin/modprobe -r mt7921_common
      ${pkgs.kmod}/bin/modprobe -r mt792x_lib
      sleep 1

      # Reload the driver
      ${pkgs.kmod}/bin/modprobe mt7921e
      sleep 1

      # Bring interface back up if we found one
      if [ -n "$WIFI_INTERFACE" ]; then
        echo "Bringing up WiFi interface: $WIFI_INTERFACE"
        ${pkgs.iproute2}/bin/ip link set "$WIFI_INTERFACE" up
      fi

      # AMD GPU display wake workaround
      # Force display refresh after hibernate resume
      echo "Triggering display wake..."
      # Try to wake DPMS
      ${pkgs.systemd}/bin/loginctl lock-session || true
      ${pkgs.systemd}/bin/loginctl unlock-session || true
    '';
    mode = "0755"; # Make executable
  };

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  system.stateVersion = "25.05";
}
