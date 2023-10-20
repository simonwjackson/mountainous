{ pkgs, config, inputs, outputs, ... }:
let
  username = builtins.baseNameOf ./.;
  ifTheyExist =
    groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [

  ];

  age.secrets."user-${username}".file = ../../../secrets/user-${username}.age;

  users.mutableUsers = false;

  security.sudo = {
    wheelNeedsPassword = false;
    extraRules = [{
      users = [ username ];

      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" "SETENV" ];
      }];
    }];
  };

  # Move up one level. ex: default.nix
  # Enable automatic login for the user.
  services.getty.autologinUser = "${username}";

  programs.zsh.enable = true;

  users.users."${username}" = {
    createHome = true;
    group = "users";
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets."user-${username}".path;
    uid = 1000;
    shell = pkgs.zsh;

    extraGroups = ifTheyExist [
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
    ];

    openssh.authorizedKeys.keys = [
      (builtins.readFile ./id_rsa.pub)
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlS7mK1MSLJviO83iAxwE5FQOu6FU9IeY6qcj6qYZ1s8qevcgj94CKhLq/ud/TexZ3qWVHkidmX0idQ4eo10lCYhAMynxT4YbtXDvHzWeeAYVN9JGyBdl4+HNctzdIKDrdOZzu+MBKgXjshuSntMUIabe7Bes+5B75ppwWqANFNPMKUSqTENxvmZ6mHF+KdwOI1oXYvOHD5y3t1dtWWcLMrot6F/ZUae5L7sRp+PqykOV4snI06uTeUxs0cTZJULDwNgngqIG9qs72BCfVvuOOwYosezUoajikPzzbBOJBl6l3M7MSJQfilVgvT/gHAxJKuZ1RzrPrssYBCbVanEL6dXuhiI25yxQvIqxDJmLzI9hvVwGgJJzov9BduO+vvPX/AwMd1oLxScgISkK/y+6+VHz+ey88gVniw22mSG0ueG11eebtp9c/lmBpNxZ30gmaINbgxZn4sM99RtC3E8eJ+KmKet8L+tFtVdeCYB7pgk8k/h06s9s3r34TGJ+SmrU="
    ];

    packages = with pkgs; [
      home-manager
    ];

  };

  environment.pathsToLink = [ "/share/zsh" ];
}
