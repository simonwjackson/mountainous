# Quickshell with Quickshell.iconTheme: the shell sets the process-wide icon
# theme when the desktop theme changes, and every later iconPath() URL names
# that theme, so Qt's pixmap cache cannot return the previous theme's icon.
# lib/patches/quickshell-icon-theme.patch; upstream has no runtime setter.
# Also expose MPRIS track object paths as strings in QML metadata, so media
# hold can distinguish Pyxamp's own playback from its forwarded player.
# Explicit transport commands bypass cached status, so short takes can undo
# an in-flight Pause before its status update reaches Quickshell.
{ pkgs }:
pkgs.quickshell.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./patches/quickshell-icon-theme.patch
    ./patches/quickshell-mpris-track-id.patch
    ./patches/quickshell-mpris-transport.patch
  ];
})
