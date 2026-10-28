# Icon and cursor themes for both desktop themes, generated from locked
# inputs. Apple- and Microsoft-derived art (Chi-Nata, Chicago95) is read from
# the inputs at build time and never copied into this repository.
{ pkgs, inputs }:
let
  fonts = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "desktop-art";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [
    (pkgs.python3.withPackages (p: [ p.pillow ]))
    pkgs.gtk3 # gtk-update-icon-cache
  ];
  buildPhase = ''
    runHook preBuild
    python3 ${../scripts/generate-desktop-art.py} --out "$out" \
      --registry ${../modules/quickshell/themes.json} \
      --web-apps ${../modules/web-apps.json} \
      --chicago ${inputs.chicago95-src} \
      --chi-nata ${inputs.chi-nata-src} \
      --retrosmart ${inputs.retrosmart-cursors-src} \
      --platinum-font ${fonts.chicagoflf}/share/fonts/truetype/ChicagoFLF.ttf \
      --win98-font ${fonts.w95fa-grid}/share/fonts/truetype/W95FAGrid.ttf
    # GTK and Qt read this cache instead of probing every directory.
    for theme in "$out"/share/icons/{Mountainous-platinum,Mountainous-win98,Chicago95}; do
      gtk-update-icon-cache --force --ignore-theme-index "$theme"
    done
    runHook postBuild
  '';
  dontInstall = true;
  # gtk3's setup hook would delete the caches made above.
  dontDropIconThemeCache = true;
  meta = {
    description = "Platinum and Windows 98 icon and cursor themes";
    # Chi-Nata: CC BY-SA 4.0. Retrosmart: GPL-3.0. Chicago95: GPL-3.0+/MIT.
    license = with pkgs.lib.licenses; [
      cc-by-sa-40
      gpl3Only
      gpl3Plus
      mit
    ];
    platforms = pkgs.lib.platforms.linux;
  };
}
