{ config, pkgs, lib, ... }:
let
  cfg = config.programs.vinyl-vault;
  package = pkgs.vinyl-vault;
in
{
  options.programs.vinyl-vault = {
    enable = lib.mkEnableOption "vinyl-vault";

    rootDownloadPath = lib.mkOption {
      default = null;
      type = with lib.types; nullOr str;
      description = ''
        
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [ package ];
      sessionVariables.VINYL_VAULT_DOWNLOAD_DIR = lib.optionalString (cfg.rootDownloadPath != null) cfg.rootDownloadPath;
    };
  };
}
