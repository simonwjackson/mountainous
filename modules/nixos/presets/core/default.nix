# { config, lib, pkgs, ... }:
#
# with lib;
# with lib.nixcfg;
#
# let
#   cfg = config.nixcfg.presets.core;
# in {
#   options.nixcfg.presets.core = with types; {
#     enable   = mkBoolOpt' false;
#     user     = mkStrOpt'  "admin";
#     hostname = mkStrOpt'  "nixos";
#     layout   = mkStrOpt'  "us";
#     locale   = mkStrOpt'  "en_US.UTF-8";
#     timezone = mkStrOpt'  "America/New_York";
#     ssh-keys = mkOpt' (listOf str) [];
#     nixcfg-dir = mkStrOpt' "/home/${cfg.user}/.config/nixcfg";
#   };
#
#   config = mkIf cfg.enable {
#     # ensure the system can boot
#     nixcfg.features.systemd-boot.enable = true;
#
#     # ensure the system can connect to the internet
#     networking.hostName = cfg.hostname;
#     networking.networkmanager.enable = true;
#
#     # assign the machine id
#     environment.etc.machine-id.source = "/persist/etc/machine-id";
#
#     # ensure the system can be accessed remotely via ssh
#     nixcfg.features.openssh.enable = true;
#
#     # configure the keyboard layout
#     services.xserver.xkb.layout = cfg.layout;
#     console.keyMap = cfg.layout;
#
#     # set the locale and timezone
#     i18n.defaultLocale = cfg.locale;
#     time.timeZone = cfg.timezone;
#
#     # disable sudo password prompts
#     security.sudo.wheelNeedsPassword = false;
#
#     # set environment variables
#     environment.variables = {
#       NIXCFG_DIR = cfg.nixcfg-dir;
#     };
#
#     # enable just command runner
#     nixcfg.features.just.enable = true;
#
#     # secrets for this machine
#     age.secrets = {
#       password.file = ../../../../secrets/systems/${cfg.hostname}/password.age;
#     };
#
#     # configure the users of this system
#     users.users = {
#       root.hashedPasswordFile = config.age.secrets.password.path;
#       "${cfg.user}" = {
#         isNormalUser = true;
#         hashedPasswordFile = config.age.secrets.password.path;
#         extraGroups = [ "wheel" "networkmanager" ];
#         openssh.authorizedKeys.keys = cfg.ssh-keys;
#       };
#     };
#
#     # configure persistent files via impermanence
#     nixcfg.features.persistence = {
#       enable = true;
#       users = [ cfg.user ];
#
#       directories = [
#         cfg.nixcfg-dir
#         "/var/log"
#         "/var/lib/nixos"
#         "/var/lib/systemd/coredump"
#         "/etc/NetworkManager/system-connections"
#         "/var/lib/bluetooth"
#       ];
#       files = [];
#
#       userDirectories = [
#         "Desktop"
#         "Documents"
#         "Downloads"
#         "Music"
#         "Pictures"
#         "Projects"
#         "Public"
#         "Templates"
#         "Videos"
#       ];
#       userFiles = [
#         ".bash_history"
#       ];
#     };
#   };
# }
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  imports = [
  ];

  age.secrets."user-simonwjackson".file = ../../../../secrets/user-simonwjackson.age;
  age.secrets."user-simonwjackson-anthropic" = {
    file = ../../../../secrets/user-simonwjackson-anthropic.age;
    owner = "simonwjackson";
    group = "users";
  };

  users.mutableUsers = false;
  programs.myNeovim = {
    enable = true;
    environment = {
      NOTES_DIR = "/glacier/snowscape/notes";
    };
    environmentFiles = [
      config.age.secrets."user-simonwjackson-anthropic".path
    ];
  };

  security.rtkit.enable = true;
  security.sudo = {
    wheelNeedsPassword = false;
    extraRules = [
      {
        users = ["simonwjackson"];

        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD" "SETENV"];
          }
        ];
      }
    ];
  };

  programs.zsh.enable = true;

  users.users.simonwjackson = {
    createHome = true;
    group = "users";
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets."user-simonwjackson".path;
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
      mountainous.ex
    ];
  };

  security.pam.loginLimits = [
    {
      domain = "@wheel";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "simonwjackson";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "simonwjackson";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  # Auto tune the CPU based on usage
  services.auto-cpufreq.enable = true;

  # HACK: non-reliable way to check if host is intel
  services.thermald.enable = lib.mkIf (config.hardware.cpu.intel.updateMicrocode) true;

  environment.pathsToLink = ["/share/zsh"];
}
