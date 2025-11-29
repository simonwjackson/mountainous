{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  enable = mkEnableOption "agenix secrets management";

  autoDiscover = mkOption {
    type = types.bool;
    default = true;
    description = "Whether to auto-discover secrets from the appropriate directory";
  };

  installCli = mkOption {
    type = types.bool;
    default = true;
    description = "Whether to install the agenix CLI tool";
  };
}
