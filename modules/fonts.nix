# System typography and fontconfig defaults for the desktop.
{ inputs, ... }:
let
  terminal-fonts =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "mountainous-terminal-fonts";
      version = "1";
      dontUnpack = true;
      nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
      buildPhase = ''
        python3 -m zipfile -e ${inputs.profont-src} profont
        python3 ${../scripts/terminal-fonts.py} fixedsys ${inputs.fixedsys-src}/FSEX.ttx Fixedsys.ttf
        python3 ${../scripts/terminal-fonts.py} profont profont/profontiix/ProFontIIx.ttf ProFontIIxGrid.ttf
      '';
      installPhase = ''
        install -Dm644 Fixedsys.ttf "$out/share/fonts/truetype/Fixedsys.ttf"
        install -Dm644 Fixedsys-Bold.ttf "$out/share/fonts/truetype/Fixedsys-Bold.ttf"
        install -Dm644 ProFontIIxGrid-Bold.ttf "$out/share/fonts/truetype/ProFontIIxGrid-Bold.ttf"
        install -Dm644 ProFontIIxGrid.ttf "$out/share/fonts/truetype/ProFontIIxGrid.ttf"
        install -Dm644 ${inputs.fixedsys-src}/README.md "$out/share/licenses/terminal-fonts/Fixedsys-README.md"
        install -Dm644 profont/profontiix/LICENSE "$out/share/licenses/terminal-fonts/ProFont-LICENSE"
      '';
      meta.license = with pkgs.lib.licenses; [
        cc0
        mit
      ];
    };
  # One font implementation for the shell and standalone Hensou applications.
  # Keep Hensou's tested nixpkgs pin; do not rebuild these with fleet overrides.
  chicagoflf = pkgs: inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.chicagoflf;
  w95fa-grid = pkgs: inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.w95fa-grid;

in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.terminal-fonts = terminal-fonts pkgs;
      checks.terminal-fonts =
        pkgs.runCommand "terminal-fonts"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
          }
          ''
            python3 ${../tests/terminal-fonts.py} ${terminal-fonts pkgs}/share/fonts/truetype \
              ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf \
              ${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFontMono-Regular.ttf
            touch $out
          '';
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
            dejavu_fonts
            nerd-fonts.symbols-only
          ])
          ++ [
            (terminal-fonts pkgs)
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
