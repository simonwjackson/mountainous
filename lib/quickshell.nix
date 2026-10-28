# Quickshell with Quickshell.iconTheme: the shell sets the process-wide icon
# theme when the desktop theme changes, and every later iconPath() URL names
# that theme, so Qt's pixmap cache cannot return the previous theme's icon.
# lib/patches/quickshell-icon-theme.patch; upstream has no runtime setter.
{ pkgs }:
pkgs.quickshell.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./patches/quickshell-icon-theme.patch ];
})
