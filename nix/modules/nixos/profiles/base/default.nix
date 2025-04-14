# This file (and the global directory) holds config that i use on all hosts
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
in {
  options.mountainous.profiles.base = {
    enable = mkEnableOption "Whether to enable the base profile.";
  };

  config = lib.mkIf config.mountainous.profiles.base.enable {
    ###################
    # Mountainous
    ###################

    mountainous = {
      user = {
        enable = mkDefault true;
        name = mkDefault "simonwjackson";
        # hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
        # authorizedKeys = let
        #   keysDir = ../../../../../keys/users;
        #   isPublicKey = name: type: type == "regular" && lib.hasSuffix ".pub" name;
        #   pubKeyFiles = lib.filterAttrs isPublicKey (builtins.readDir keysDir);
        #   keys = lib.mapAttrsToList (name: _: builtins.readFile (keysDir + "/${name}")) pubKeyFiles;
        # in
        #   keys;
      };
    };
    ###################
    # Misc
    ###################

    users = {
      groups.media = {
        gid = lib.mkForce 333;
      };

      users.media = {
        homeMode = "770";
        group = "media";
        uid = lib.mkForce 333;
        isNormalUser = false;
      };
    };

    # services.sunshine = {
    #   openFirewall = lib.mkDefault true;
    #   capSysAdmin = lib.mkDefault true;
    #   settings = {
    #     log_path = lib.mkDefault "/tmp/sunshine.log";
    #     key_rightalt_to_key_win = lib.mkDefault "enabled";
    #   };
    #   autoStart = lib.mkDefault false;
    # };

    # services.udev.extraRules = ''
    #   KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    #   KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    # '';

    # environment.pathsToLink = ["/share/zsh"];

    # TODO: Move to (desktop?) profile
    environment.variables.BROWSER = "firefox";

    services.gpm.enable = true; # TTY mouse

    # This is a hack to get around a bug in nixos-option
    # TODO: Remove this when nixos-option is fixed
    # INFO: https://github.com/NixOS/nixpkgs/issues/291051
    environment.etc."NIXOS_OZONE_WL".text = "1";

    # Enable flakes
    nix.settings.experimental-features = ["nix-command" "flakes"];
  
    hardware = {
      enableRedistributableFirmware = true;
      enableAllFirmware = true;
    };

    # Enable SSH
    services.openssh.enable = true;

    # Network configuration
    networking = {
      networkmanager.enable = true;
    };

    # Time zone and locale
    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";
  };
}
