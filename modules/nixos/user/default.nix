{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) str listOf path attrs;

  cfg = config.mountainous.user;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  options.mountainous.user = {
    enable = mkEnableOption "Whether to enable the main user account.";

    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.name}";
      description = "The home directory for the user.";
    };

    name = mkOption {
      type = str;
      default = "admin";
      description = "The name to use for the user account.";
    };

    fullName = mkOption {
      type = str;
      default = "Admin";
      description = "The full name of the user.";
    };

    email = mkOption {
      type = str;
      default = "admin@localhost";
      description = "The email of the user.";
    };

    extraGroups = mkOption {
      type = listOf str;
      default = [];
      description = "Groups for the user to be assigned.";
    };

    extraOptions = mkOption {
      type = attrs;
      default = {};
      description = "Extra options passed to `users.users.<name>`.";
    };

    hashedPasswordFile = mkOption {
      type = path;
      default = null;
      description = "The path to a file containing the hashed password for the user.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        The user ID for the user accounti. Since I only
        have a single user on my machines this won't ever collide.
        However, if you add multiple users you'll need to change this
        so each user has their own unique uid (or leave it out for the
        system to select).
      '';
    };

    authorizedKeys = mkOption {
      type = listOf str;
      description = "The list of authorized SSH keys for the user.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
    '';

    users = {
      mutableUsers = true;
      users.${cfg.name} =
        {
          isNormalUser = true;
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
          hashedPasswordFile = cfg.hashedPasswordFile;
          home = cfg.home;
          group = "users";
          extraGroups =
            ifTheyExist [
              "audio"
              "deluge"
              "dialout"
              "disk"
              "docker"
              "git"
              "i2c"
              "libvirtd"
              "minecraft"
              "network"
              "networkmanager"
              "podman"
              "video"
              "wheel"
              "steamcmd"
            ]
            ++ cfg.extraGroups;
          shell = pkgs.zsh;
          uid = cfg.uid;
        }
        // cfg.extraOptions;
    };
  };
}
