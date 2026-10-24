# The flake-parts self is captured here; no extra NixOS specialArgs are needed.
{ self, ... }:
{
  nixos.modules.desktop =
    { lib, ... }:
    {
      system.configurationRevision = lib.mkDefault (self.rev or self.dirtyRev or null);
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.desktop-safety =
        pkgs.runCommand "desktop-safety"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.quickshell
              pkgs.labwc
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
          }
          ''
            node ${./quickshell/launcher-model.test.js} ${./quickshell/launcher-model.js} ${./quickshell}
            node ${./quickshell/desktop-safety.test.js} ${./quickshell}
            touch $out
          '';
    };
}
