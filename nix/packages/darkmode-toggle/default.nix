{
  lib,
  writeShellApplication,
  kitty,
  kitty-themes,
  dconf,
  glib,
  coreutils,
  gnugrep,
  gsettings-desktop-schemas,
  iproute2,
  inputs,
  # Theme configuration parameters
  kittyDarkTheme ? "tokyo_night_night.conf",
  kittyLightTheme ? "tokyo_night_day.conf",
  gtkDarkTheme ? "tokyonight-dark-b",
  gtkLightTheme ? "tokyonight-day-b",
}:
writeShellApplication {
  name = "darkmode-toggle";
  runtimeInputs = [kitty dconf glib coreutils gnugrep gsettings-desktop-schemas iproute2];
  text = ''
    export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:$XDG_DATA_DIRS"
    export KITTY_THEMES_DIR="${kitty-themes}/share/kitty-themes/themes"
    export KITTY_DARK_THEME="$KITTY_THEMES_DIR/${kittyDarkTheme}"
    export KITTY_LIGHT_THEME="$KITTY_THEMES_DIR/${kittyLightTheme}"
    export GTK_DARK_THEME="${gtkDarkTheme}"
    export GTK_LIGHT_THEME="${gtkLightTheme}"
    ${builtins.readFile ./darkmode-toggle.sh}
  '';
}
