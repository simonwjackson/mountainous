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
  inherit (lib.types) bool;

  cfg = config.mountainous.networking.secure-shell;
in {
  options.mountainous.networking.secure-shell = {
    enable = mkEnableOption "Whether to enable ssh and mosh";

    harden = mkOption {
      type = bool;
      default = true;
      description = "Whether to enable hardening options for SSH";
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

    # FIX: Get list of managed hosts
    # programs.ssh = {
    #   # Each hosts public key
    #   knownHosts =
    #     builtins.mapAttrs
    #     (name: _: {
    #       publicKey = pubKey name;
    #       extraHostNames =
    #         (lib.optional (name == hostName) "localhost")
    #         ++ [
    #           "${name}.hummingbird-lake.ts.net"
    #           # TODO: Grab this from somwhere else in to config
    #           "${name}.mountaino.us"
    #         ];
    #     })
    #     allManagedHosts;
    # };

    security.pam.sshAgentAuth.enable = true;
    programs.mosh.enable = true;
  };
}
