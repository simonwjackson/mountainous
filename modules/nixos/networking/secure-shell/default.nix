{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  inherit (config.networking) hostName;
  inherit (lib) mkOption mkEnableOption mkIf optionalAttrs;
  inherit (lib.types) listOf bool str path;
  inherit (lib.mountainous) knownHostsBuilder;

  cfg = config.mountainous.networking.secure-shell;
in {
  options.mountainous.networking.secure-shell = {
    enable = mkEnableOption "Whether to enable ssh and mosh";

    harden = mkOption {
      type = bool;
      default = true;
      description = "Whether to enable hardening options for SSH";
    };

    systemsDir = mkOption {
      type = path;
      description = "";
    };

    domains = mkOption {
      type = listOf str;
      default = [];
      description = "";
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings =
        {
        }
        // optionalAttrs cfg.harden {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
    };

    programs.ssh = {
      knownHosts =
        knownHostsBuilder {
          systemsDir = cfg.systemsDir;
          domains = cfg.domains;
          localhost = hostName;
        }
        // {
          "github.com" = {
            extraHostNames = ["ssh.github.com"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          };
        };
    };

    security.pam.sshAgentAuth.enable = true;
    programs.mosh.enable = true;
  };
}
