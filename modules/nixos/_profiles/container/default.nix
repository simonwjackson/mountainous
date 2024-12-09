{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.container;
in {
  options.mountainous.profiles.container = {
    enable = lib.mkEnableOption "Whether to enable container configurations";
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
      "fs.inotify.max_user_watches" = 524288;
    };

    networking = {
      useHostResolvConf = false;
    };

    services.resolved = {
      enable = true;
      dnssec = "false";
    };

    users = {
      groups.media = {
        gid = lib.mkForce 333;
      };

      users.media = {
        homeMode = "770";
        group = "media";
        uid = lib.mkForce 333;
        isNormalUser = false;
        isSystemUser = true;
        hashedPassword = "!";
      };
    };
  };
}
