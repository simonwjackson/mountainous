{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkOption optional types;
in {
  imports = optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.features.ssh = {
    server = {
      enable = mkEnableOption "SSH server";

      port = mkOption {
        type = types.port;
        default = 2345;
        description = "Port for the SSH server.";
      };

      authorizedKeysUrl = mkOption {
        type = types.nullOr types.str;
        default = "https://github.com/simonwjackson.keys";
        example = "https://github.com/simonwjackson.keys";
        description = "URL to fetch authorized keys from if none exist locally.";
      };

      allowedCidrs = mkOption {
        type = types.listOf types.str;
        default = ["100.64.0.0/10"];
        example = ["100.64.0.0/10"];
        description = "Client CIDR ranges allowed to connect to sshd.";
      };

      mosh = {
        enable = mkEnableOption "Mosh remote shell support";

        ports = mkOption {
          type = types.str;
          default = "60000:60010";
          example = "60000:60010";
          description = "UDP port range used by mosh-server for remote sessions.";
        };
      };
    };
  };
}
