{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: let
  passwordSecretFile = ../../secrets/hosts/yuki/simonwjackson-password-hash.age;
  hasPasswordSecret = builtins.pathExists passwordSecretFile;
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./workarounds.nix
    ../../nix/profiles/laptop
    ../../nix/profiles/workstation
    ../../nix/modules/nixos/device
    ../../nix/features/gaming/nixos.nix
  ];

  home-manager.users.simonwjackson = {
    imports = [
      ../../home/simonwjackson
      ../../nix/features/gaming/home.nix
      hyprdynamicmonitors.homeManagerModules.default
    ];
  };

  networking.hostName = "yuki";
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  mountainous.profiles = {
    laptop.enable = true;
    workstation.enable = true;
  };

  mountainous.device = {
    role = "portable";
    capabilities = {
      battery = true;
      formFactor = "laptop";
      touchscreen = false;
    };
  };

  nixpkgs.config.allowUnfree = true;

  mountainous.gaming.enable = true;

  age.secrets.simonwjackson-password-hash = lib.mkIf hasPasswordSecret {
    file = passwordSecretFile;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  users.users.simonwjackson =
    {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
      ];
    }
    // lib.optionalAttrs hasPasswordSecret {
      hashedPasswordFile = config.age.secrets.simonwjackson-password-hash.path;
    };

  boot = {
    # Arrow Lake-H suspend-to-idle support requires Linux 6.15 or newer.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 20480;
    }
  ];

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=15min
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
    HandleHibernateKey = "hibernate";
  };

  services.upower.enable = true;

  # Favor maximum performance on AC while keeping an aggressive battery-saver
  # profile when unplugged.
  services.auto-cpufreq.enable = lib.mkForce false;
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 0;

    WIFI_PWR_ON_AC = "off";
    WIFI_PWR_ON_BAT = "on";
  };

  # Keep Hyprland wiring local here instead of importing nix/features/hyprland/nixos.nix:
  # that module assumes a separate hyprland flake input and configures SDDM/autologin,
  # while yuki should use greetd + tuigreet.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = "*";
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
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

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # gaming module enables graphics, pipewire, and rtkit
  # just add the 32-bit extras for native 32-bit apps
  hardware.graphics.enable32Bit = true;

  services.xserver.videoDrivers = ["modesetting"];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  systemd.services.unblock-bluetooth = {
    description = "Unblock Bluetooth on boot";
    wantedBy = [
      "bluetooth.target"
      "multi-user.target"
    ];
    after = ["systemd-rfkill.service"];
    before = ["bluetooth.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
