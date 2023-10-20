{ config, pkgs, lib, ... }:

let
  cfg = config.programs.nest-tmux;
  package = pkgs.nest-tmux;
in
{
  options.programs.nest-tmux = {
    enable = lib.mkEnableOption "nest-tmux";

    servers = lib.mkOption {
      default = [ "unzen" "fiji" ];
      type = with lib.types; listOf str; # list of strings
      description = ''
        Show a list of all servers that can be switched to
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [ package ];
      sessionVariables.TMUX_ALL_SERVERS = builtins.concatStringsSep "\n" cfg.servers;
    };
  };
}
