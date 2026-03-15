{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: let
  passwordSecretFile = ../../secrets/hosts/yuki/simonwjackson-password-hash.age;
  hasPasswordSecret = builtins.pathExists passwordSecretFile;
  syncthingShares = import ./syncthing-shares.nix;
  syncthingFolders =
    lib.mapAttrs (
      name: hostCfg: let
        shareCfg = import (../../home/simonwjackson/syncthing + "/${name}.nix");
      in
        assert (shareCfg.name or name) == name;
          (builtins.removeAttrs shareCfg ["name"]) // hostCfg
    )
    syncthingShares;

  yukiKanataConfig = pkgs.writeText "yuki-kanata.kbd" ''
    (defcfg
      process-unmapped-keys yes
      concurrent-tap-hold yes
      linux-continue-if-no-devs-found yes
    )

    (defsrc
      a s h j k l u i o m comm . left down up right esc ret spc
    )

    (defalias
      a-arr (tap-hold 200 200 a (layer-while-held arrows))
      s-pad (tap-hold 200 200 s (layer-while-held numpad))
      spc-met (tap-hold 200 200 spc lmet)
    )

    (defchordsv2
      (j k) (macro ret) 150 first-release (arrows)
      (k l) (macro esc) 150 first-release (arrows)
    )

    (deflayer base
      @a-arr @s-pad h j k l u i o m comm . XX XX XX XX XX XX @spc-met
    )

    (deflayer arrows
      a s left down up right u i o m comm . XX XX XX XX XX XX @spc-met
    )

    (deflayer numpad
      a s h kp4 kp5 kp6 kp7 kp8 kp9 kp1 kp2 kp3 XX XX XX XX XX XX kp0
    )
  '';
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./quirks.nix
    ../../modules/nixos/device
    ../../features/gaming/nixos.nix
  ];

  home-manager.users.simonwjackson = {
    imports = [
      ../../home/simonwjackson
      ../../features/gaming/home.nix
      ../../modules/home/theme
      hyprdynamicmonitors.homeManagerModules.default
    ];

    mountainous.theme = {
      enable = lib.mkDefault true;
      defaultMode = lib.mkDefault "dark";
    };

    home.packages = [pkgs.lazygit];
  };

  networking.hostName = "yuki";

  mountainous.features.firefox = {
    enable = true;
    cascade.enable = true;
  };

  mountainous.syncthing = {
    enable = true;
    folders = syncthingFolders;
  };
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  mountainous.device = {
    role = "portable";
    capabilities = {
      battery = true;
      formFactor = "laptop";
      touchscreen = false;
    };
  };

  programs.dconf.enable = lib.mkDefault true;

  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
  ];

  environment.systemPackages = with pkgs; [
    acpi
    kanata
  ];

  networking.networkmanager.wifi.powersave = lib.mkDefault true;

  services.udev.extraRules = ''
    # Ignore only the ThinkPad Bluetooth keyboard's integrated touchpad.
    # Leave yuki's built-in touchpad, keyboard, pen, and touchscreen alone.
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="ThinkPad Bluetooth TrackPoint Keyboard Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    # Keep /dev/uinput available for the host-level Kanata remapper.
    KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
  '';

  services = {
    geoclue2 = {
      enable = true;
      enableDemoAgent = true;
      geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
      submissionUrl = "https://api.beacondb.net/v2/geosubmit";
      appConfig = {
        automatic-timezoned = {
          isAllowed = true;
          isSystem = true;
          users = [];
        };
        gammastep = {
          isAllowed = true;
          isSystem = false;
          users = [];
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };

    timesyncd.enable = lib.mkDefault true;
    tlp.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault (config.hardware.cpu.intel.updateMicrocode or false);
    power-profiles-daemon.enable = lib.mkDefault false;
    libinput = {
      enable = true;
      touchpad = {
        disableWhileTyping = true;
        tapping = true;
      };
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
    kernelModules = ["uinput"];
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 20480;
    }
  ];

  systemd.services.kanata = {
    description = "Kanata keyboard remapper";
    wantedBy = ["multi-user.target"];
    after = ["systemd-udevd.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kanata}/bin/kanata --cfg ${yukiKanataConfig}";
      Restart = "always";
      RestartSec = "3";
      User = "root";
      Group = "root";
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      DeviceAllow = [
        "/dev/uinput rw"
        "char-input r"
      ];
    };
  };

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

  # Keep Hyprland wiring local here instead of importing an older shared Hyprland module:
  # that module assumed a separate hyprland flake input and configured SDDM/autologin,
  # while yuki should use greetd + tuigreet.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.darkman pkgs.xdg-desktop-portal-gtk];
    config.common = {
      default = "*";
      "org.freedesktop.impl.portal.Settings" = ["darkman"];
    };
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
