{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.features.mosh;
  moshServerWrapper = pkgs.writeShellScriptBin "mosh-server" ''
    export LANG="''${LANG:-C.UTF-8}"
    export LC_CTYPE="''${LC_CTYPE:-$LANG}"
    exec ${pkgs.mosh}/bin/mosh-server "$@"
  '';
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.mountainous.features.sshd.enable;
        message = "mountainous.features.mosh.enable requires mountainous.features.sshd.enable = true.";
      }
    ];

    environment.packages = [
      (lib.hiPrio moshServerWrapper)
      pkgs.mosh
    ];
  };
}
