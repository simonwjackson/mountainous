# Fixed Platinum at boot (choice a): no privileged user-session ESP writer,
# no theme-switch rebuild. Both theme packages can be previewed/tested.
{ self, ... }:
let
  bootThemes =
    pkgs:
    import ../lib/desktop-boot.nix {
      inherit pkgs;
      platinumFont = "${
        self.packages.${pkgs.stdenv.hostPlatform.system}.chicagoflf
      }/share/fonts/truetype/ChicagoFLF.ttf";
      win98Font = "${
        self.packages.${pkgs.stdenv.hostPlatform.system}.w95fa-grid
      }/share/fonts/truetype/W95FAGrid.ttf";
    };
in
{
  perSystem = { pkgs, ... }: {
    packages.desktop-boot-themes = bootThemes pkgs;
    checks.desktop-boot = pkgs.testers.runNixOSTest (
      import ../tests/desktop-boot.nix {
        inherit pkgs;
        themes = bootThemes pkgs;
      }
    );
  };
  nixos.modules.desktop = { lib, pkgs, ... }: {
    boot.plymouth = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "mountainous-platinum";
      themePackages = [ (bootThemes pkgs) ];
      showDelay = lib.mkDefault 0;
      # Bound renderer discovery; late KMS must fall back rather than delay
      # an encrypted boot. The upstream module otherwise uses eight seconds.
      extraConfig = "DeviceTimeout=0.1";
    };
  };
}
