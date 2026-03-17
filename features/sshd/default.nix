{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.sshd;
in {
  options.mountainous.features.sshd = {
    enable = mkEnableOption "SSH server";

    port = mkOption {
      type = types.port;
      default = 2345;
      description = "Port for the SSH server.";
    };

    authorizedKeysUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
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
}
