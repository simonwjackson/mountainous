# System typography and fontconfig defaults for the desktop.
{ inputs, ... }:
let
  chicagoflf =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "chicagoflf";
      version = "2.1";
      src = inputs.chicagoflf-src;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        install -Dm644 ChicagoFLF.ttf "$out/share/fonts/truetype/ChicagoFLF.ttf"
        install -Dm644 README.ChicagoFLF "$out/share/doc/chicagoflf/README.ChicagoFLF"
        runHook postInstall
      '';
      meta = {
        description = "ChicagoFLF classic Macintosh outline font";
        homepage = "https://fontlibrary.org/en/font/chicagoflf";
        # The designer's public-domain statement ships in README.ChicagoFLF.
        license = pkgs.lib.licenses.publicDomain;
        platforms = pkgs.lib.platforms.all;
      };
    };
  w95fa-grid =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "w95fa-grid";
      version = "1.002-grid1";
      src = inputs.w95fa-src;
      nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
      buildPhase = ''
        runHook preBuild
        python3 ${../scripts/w95fa-grid.py} W95FA/W95FA.otf W95FAGrid.ttf
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        install -Dm644 W95FAGrid.ttf "$out/share/fonts/truetype/W95FAGrid.ttf"
        install -Dm644 W95FA/OFL.txt "$out/share/licenses/w95fa-grid/OFL.txt"
        runHook postInstall
      '';
      meta = {
        description = "W95FA Grid pixel-aligned Windows 95/98 UI font";
        homepage = "https://fontsarena.com/w95fa/";
        license = pkgs.lib.licenses.ofl;
        platforms = pkgs.lib.platforms.all;
      };
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.chicagoflf = chicagoflf pkgs;
      packages.w95fa-grid = w95fa-grid pkgs;
      checks.w95fa-grid =
        pkgs.runCommand "w95fa-grid-font"
          {
            nativeBuildInputs = [
              pkgs.fontconfig
              (pkgs.python3.withPackages (p: [ p.fonttools ]))
            ];
          }
          ''
            export HOME="$TMPDIR"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            mkdir -p "$XDG_CACHE_HOME/fontconfig"
            font=${w95fa-grid pkgs}/share/fonts/truetype/W95FAGrid.ttf
            test "$(fc-scan --format '%{family}' "$font")" = 'W95FA Grid'
            python3 ${../tests/w95fa-grid.py} "$font"
            cmp ${inputs.w95fa-src}/W95FA/OFL.txt ${w95fa-grid pkgs}/share/licenses/w95fa-grid/OFL.txt
            touch $out
          '';
      checks.chicagoflf =
        pkgs.runCommand "chicagoflf-family"
          {
            nativeBuildInputs = [ pkgs.fontconfig ];
          }
          ''
            export HOME="$TMPDIR"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            mkdir -p "$XDG_CACHE_HOME/fontconfig"
            test "$(fc-scan --format '%{family}' ${chicagoflf pkgs}/share/fonts/truetype/ChicagoFLF.ttf)" = ChicagoFLF
            grep -F 'PUBLIC DOMAIN' ${chicagoflf pkgs}/share/doc/chicagoflf/README.ChicagoFLF
            touch $out
          '';
    };

  nixos.modules.desktop =
    { pkgs, ... }:
    {
      fonts = {
        packages =
          (with pkgs; [
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
            inter
          ])
          ++ [
            (chicagoflf pkgs)
            (w95fa-grid pkgs)
          ];
        fontconfig = {
          defaultFonts = {
            sansSerif = [
              "Inter"
              "Noto Sans"
              "DejaVu Sans"
            ];
            monospace = [
              "DejaVu Sans Mono"
            ];
            serif = [
              "DejaVu Serif"
            ];
            emoji = [
              "Noto Color Emoji"
            ];
          };
          # OLED panels with non-standard subpixel layouts benefit from disabling
          # subpixel color fringing.
          subpixel.rgba = "none";
        };
      };
    };
}
