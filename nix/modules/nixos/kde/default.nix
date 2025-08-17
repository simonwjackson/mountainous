{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.kde;
in {
  options.mountainous.kde = {
    enable = mkEnableOption "KDE Plasma desktop environment";

    autoLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic login";
    };

    autoLoginUser = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to automatically log in";
    };
  };

  config = mkIf cfg.enable {
    # Enable the X11 windowing system
    services.xserver.enable = true;

    # Enable the KDE Plasma Desktop Environment
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoLogin = mkIf cfg.autoLogin {
        enable = true;
        user = cfg.autoLoginUser;
      };
    };

    services.desktopManager.plasma6.enable = true;

    # Disable power-profiles-daemon as it conflicts with TLP
    services.power-profiles-daemon.enable = false;

    # Configure autologin without password
    services.displayManager.autoLogin = mkIf cfg.autoLogin {
      enable = true;
      user = cfg.autoLoginUser;
    };

    # Ensure the user exists and has no password requirement for autologin
    users.users.${cfg.autoLoginUser} = mkIf cfg.autoLogin {
      extraGroups = ["wheel" "video" "audio" "networkmanager"];
      # Set an empty password hash to allow passwordless login
      hashedPassword = "";
    };

    # Enable passwordless sudo for the autologin user
    security.sudo.extraRules = mkIf cfg.autoLogin [
      {
        users = [cfg.autoLoginUser];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # XDG portal for better desktop integration
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        kdePackages.xdg-desktop-portal-kde
      ];
    };

    # Enable sound
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # KDE-specific packages
    environment.systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.konsole
      kdePackages.dolphin
      kdePackages.ark
      kdePackages.spectacle
      kdePackages.okular
      kdePackages.gwenview
    ];
  };
}
