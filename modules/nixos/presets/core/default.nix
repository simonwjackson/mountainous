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
  age.secrets."user-simonwjackson".file = ../../../../secrets/user-simonwjackson.age;
  age.secrets."user-simonwjackson-anthropic" = {
    file = ../../../../secrets/user-simonwjackson-anthropic.age;
    owner = "simonwjackson";
    group = "users";
  };

  programs.myNeovim = {
    enable = true;
    environment = {
      NOTES_DIR = "/glacier/snowscape/notes";
    };
    environmentFiles = [
      config.age.secrets."user-simonwjackson-anthropic".path
    ];
  };

  programs.zsh.enable = true;

  mountainous = {
    user = {
      name = "simonwjackson";
      hashedPasswordFile = config.age.secrets."user-simonwjackson".path;
    };
  };

  environment.pathsToLink = ["/share/zsh"];
}
