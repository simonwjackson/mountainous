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
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.chicagoflf = chicagoflf pkgs;
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
          ++ [ (chicagoflf pkgs) ];
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
