{
  config,
  lib,
  pkgs,
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
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "yuki";
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  mountainous.profiles = {
    laptop.enable = true;
    workstation.enable = true;
  };

  age.secrets.simonwjackson-password-hash = lib.mkIf hasPasswordSecret {
    file = passwordSecretFile;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  users.users.simonwjackson =
    {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager" "video"];
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
    HandlePowerKey = "hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
    HandleHibernateKey = "hibernate";
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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = ["modesetting"];

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
