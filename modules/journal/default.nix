{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.journal;
  file = builtins.readFile (./journal.sh);
  script = pkgs.writeScriptBin "journal" file;
in
{
  options.programs.journal = {
    enable = mkEnableOption "Whether to enable the journal.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ script pkgs.pandoc ];
  };
}
