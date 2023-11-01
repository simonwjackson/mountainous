{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.vinyl-vault;
  package = pkgs.vinyl-vault;
in {
  options.programs.vinyl-vault = {
    enable = lib.mkEnableOption "vinyl-vault";

    rootDownloadPath = lib.mkOption {
      default = config.xdg.userDirs.music;
      type = lib.types.str;
      description = ''
        Where to download the music files to.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [package];
      sessionVariables.VINYL_VAULT_DOWNLOAD_DIR = lib.optionalString (cfg.rootDownloadPath != null) cfg.rootDownloadPath;
    };
  };
}
