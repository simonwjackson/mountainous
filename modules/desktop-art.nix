# Icons, cursors and the desktop pattern for both desktop themes (phase 4,
# docs/plans/desktop-themes/phase4-art.md). desktop-theme selects the icon
# and cursor themes; Quickshell draws the pattern from themes.json.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.platinum-icons = import ../lib/platinum-icons.nix { inherit pkgs; };
      checks.platinum-icons =
        let
          icons = import ../lib/platinum-icons.nix { inherit pkgs; };
        in
        pkgs.runCommand "platinum-icons"
          {
            nativeBuildInputs = [
              icons.python
              pkgs.librsvg
            ];
            PLATINUM_ICON = "${icons}/bin/mountainous-platinum-icon";
          }
          ''
            cp ${../scripts/platinum_icons.py} platinum_icons.py
            cp ${../scripts/platinum-icon.py} platinum-icon.py
            cp ${../scripts/platinum-app-tokens.py} platinum-app-tokens.py
            cp ${../scripts/test-platinum-icons.py} test-platinum-icons.py
            python3 test-platinum-icons.py
            touch "$out"
          '';
      packages.desktop-art = import ../lib/desktop-art.nix { inherit pkgs inputs; };
      packages.quickshell-mountainous = import ../lib/quickshell.nix { inherit pkgs; };
    };

  nixos.modules.desktop =
    { pkgs, lib, ... }:
    {
      # share/icons: Mountainous-{platinum,win98} icon themes, Chicago95,
      # and the two cursor themes (XCursor and hyprcursor in one directory).
      environment.systemPackages = [
        (import ../lib/desktop-art.nix { inherit pkgs inputs; })
        (import ../lib/platinum-icons.nix { inherit pkgs; })
      ];
      # Platinum tokens drawn at build time into the Mountainous-platinum-apps
      # theme, which Mountainous-platinum inherits first
      # (scripts/platinum-app-tokens.py): 32 px art for every app the theme
      # has none for, and the Control Strip's mountainous.strip.<name> tokens
      # for every app, at the strip's one optical size (26 px opaque at 1.5).
      # The strip draws them 1:1; nothing is resampled at run time.
      # It reads the finished system path, so it sees every app without a
      # dependency cycle; apps from a user profile are not covered.
      environment.extraSetup = ''
        if [ -d "$out/share/icons" ] && [ ! -L "$out/share/icons" ]; then
          ${
            import ../lib/platinum-icons.nix { inherit pkgs; }
          }/bin/mountainous-platinum-app-tokens "$out/share" "$out/share/icons/Mountainous-platinum-apps" \
            --covered "$out/share/icons/Mountainous-platinum"
          ${pkgs.buildPackages.gtk3.out}/bin/gtk-update-icon-cache --force --ignore-theme-index \
            "$out/share/icons/Mountainous-platinum-apps"
        fi
      '';
      # Pin the helper for the user service; do not rely on a login-shell PATH.
      systemd.user.services.quickshell.environment.MOUNTAINOUS_PLATINUM_ICON = "${
        import ../lib/platinum-icons.nix { inherit pkgs; }
      }/bin/mountainous-platinum-icon";
      # A client with no XCURSOR_THEME loads "default"; send it to the alias
      # desktop-theme keeps in ~/.icons (scripts/apply-native-theme.py).
      xdg.icons.fallbackCursorThemes = lib.mkBefore [
        "Mountainous-cursors"
        "Adwaita"
      ];
    };
}
