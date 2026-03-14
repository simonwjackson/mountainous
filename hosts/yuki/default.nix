{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  cascade,
  ...
}: let
  passwordSecretFile = ../../secrets/hosts/yuki/simonwjackson-password-hash.age;
  hasPasswordSecret = builtins.pathExists passwordSecretFile;
  syncthingShares = import ./syncthing-shares.nix;
  syncthingFolders = lib.mapAttrs (
    name: hostCfg:
      let
        shareCfg = import (../../home/simonwjackson/syncthing + "/${name}.nix");
      in
        assert (shareCfg.name or name) == name;
          (builtins.removeAttrs shareCfg [ "name" ]) // hostCfg
  ) syncthingShares;

  cascadeUserChrome = ''
    @import url("file://${cascade}/chrome/includes/cascade-config.css");
    @import url("file://${cascade}/chrome/includes/cascade-colours.css");

    @import url("file://${cascade}/chrome/includes/cascade-layout.css");
    @import url("file://${cascade}/chrome/includes/cascade-responsive.css");
    @import url("file://${cascade}/chrome/includes/cascade-floating-panel.css");

    @import url("file://${cascade}/chrome/includes/cascade-nav-bar.css");
    @import url("file://${cascade}/chrome/includes/cascade-tabs.css");

    @media (prefers-color-scheme: dark) {
      :root {
        --uc-identity-colour-blue: #7aa2f7;
        --uc-identity-colour-turquoise: #2ac3de;
        --uc-identity-colour-green: #9ece6a;
        --uc-identity-colour-yellow: #e0af68;
        --uc-identity-colour-orange: #ff9e64;
        --uc-identity-colour-red: #f7768e;
        --uc-identity-colour-pink: #ff75a0;
        --uc-identity-colour-purple: #bb9af7;

        --uc-base-colour: #1a1b26;
        --uc-highlight-colour: #24283b;
        --uc-inverted-colour: #c0caf5;
        --uc-muted-colour: #565f89;
        --uc-accent-colour: #7aa2f7;
      }
    }

    @media (prefers-color-scheme: light) {
      :root {
        --uc-identity-colour-blue: #2e7de9;
        --uc-identity-colour-turquoise: #007197;
        --uc-identity-colour-green: #587539;
        --uc-identity-colour-yellow: #8c6c3e;
        --uc-identity-colour-orange: #b15c00;
        --uc-identity-colour-red: #8c4351;
        --uc-identity-colour-pink: #c64343;
        --uc-identity-colour-purple: #7847bd;

        --uc-base-colour: #e1e2e7;
        --uc-highlight-colour: #d5d6db;
        --uc-inverted-colour: #3760bf;
        --uc-muted-colour: #848cb5;
        --uc-accent-colour: #2e7de9;
      }
    }
  '';
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./workarounds.nix
    ../../modules/nixos/device
    ../../features/gaming/nixos.nix
  ];

  home-manager.users.simonwjackson = {
    imports = [
      ../../home/simonwjackson
      ../../features/gaming/home.nix
      ../../modules/home/firefox
      ../../modules/home/theme
      hyprdynamicmonitors.homeManagerModules.default
    ];

    mountainous.theme = {
      enable = lib.mkDefault true;
      defaultMode = lib.mkDefault "dark";
    };

    home.packages = [pkgs.lazygit];

    programs.firefox.profiles.default = {
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };
      userChrome = cascadeUserChrome;
    };

    mountainous.firefox = {
      enable = lib.mkDefault true;
      extensions = lib.mkDefault {
        "uBlock0@raymondhill.net" = {slug = "ublock-origin";};
        "addon@darkreader.org" = {slug = "darkreader";};
        "sponsorBlocker@ajay.app" = {slug = "sponsorblock";};
        "@react-devtools" = {slug = "react-devtools";};
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {slug = "1password-x-password-manager";};
        "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}" = {slug = "augmented-steam";};
        "jid1-BYcQOfYfmBMd9A@jetpack" = {slug = "pushbullet";};
        "tridactyl.vim@cmcaine.co.uk" = {slug = "tridactyl-vim";};
        "ff2mpv@yossarian.net" = {slug = "ff2mpv";};
      };
      nativeMessagingHosts = lib.mkDefault [pkgs.ff2mpv];
      extraPolicies = lib.mkDefault {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
      };
    };
  };

  networking.hostName = "yuki";

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
  ];

  networking.networkmanager.wifi.powersave = lib.mkDefault true;

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
