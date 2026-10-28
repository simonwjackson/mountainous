# Icons, cursors and the desktop pattern for both desktop themes (phase 4,
# docs/plans/desktop-themes/phase4-art.md). desktop-theme selects the icon
# and cursor themes; Quickshell draws the pattern from themes.json.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.desktop-art = import ../lib/desktop-art.nix { inherit pkgs inputs; };
      packages.quickshell-mountainous = import ../lib/quickshell.nix { inherit pkgs; };
    };

  nixos.modules.desktop =
    { pkgs, lib, ... }:
    {
      # share/icons: Mountainous-{platinum,win98} icon themes, Chicago95,
      # and the two cursor themes (XCursor and hyprcursor in one directory).
      environment.systemPackages = [ (import ../lib/desktop-art.nix { inherit pkgs inputs; }) ];
      # A client with no XCURSOR_THEME loads "default"; send it to the alias
      # desktop-theme keeps in ~/.icons (scripts/apply-native-theme.py).
      xdg.icons.fallbackCursorThemes = lib.mkBefore [
        "Mountainous-cursors"
        "Adwaita"
      ];
    };
}
