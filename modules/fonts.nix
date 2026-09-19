# System typography and fontconfig defaults for the desktop.
{
  nixos.modules.desktop = {pkgs, ...}: {
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        inter
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
