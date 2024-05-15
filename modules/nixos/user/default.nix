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
  };

  config = lib.mkIf cfg.enable {
    users = {
      mutableUsers = true;
      users.${cfg.name} =
        {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [
            (builtins.readFile ./id_rsa.pub)
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlS7mK1MSLJviO83iAxwE5FQOu6FU9IeY6qcj6qYZ1s8qevcgj94CKhLq/ud/TexZ3qWVHkidmX0idQ4eo10lCYhAMynxT4YbtXDvHzWeeAYVN9JGyBdl4+HNctzdIKDrdOZzu+MBKgXjshuSntMUIabe7Bes+5B75ppwWqANFNPMKUSqTENxvmZ6mHF+KdwOI1oXYvOHD5y3t1dtWWcLMrot6F/ZUae5L7sRp+PqykOV4snI06uTeUxs0cTZJULDwNgngqIG9qs72BCfVvuOOwYosezUoajikPzzbBOJBl6l3M7MSJQfilVgvT/gHAxJKuZ1RzrPrssYBCbVanEL6dXuhiI25yxQvIqxDJmLzI9hvVwGgJJzov9BduO+vvPX/AwMd1oLxScgISkK/y+6+VHz+ey88gVniw22mSG0ueG11eebtp9c/lmBpNxZ30gmaINbgxZn4sM99RtC3E8eJ+KmKet8L+tFtVdeCYB7pgk8k/h06s9s3r34TGJ+SmrU="
          ];
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
