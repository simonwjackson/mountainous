# Hyprland window rules
{
  lib,
  pkgs,
}: {
  windowrule = [
    "suppress_event maximize, match:class .*"
    "no_focus true, match:class ^$, match:title ^$, match:xwayland true, match:float true, match:fullscreen false, match:pin false"
    "workspace magic, match:class ^(steam)$"

    # Firefox: Float specific popups and dialogs
    "float true, match:class ^(firefox)$, match:title ^(Library)$"
    "float true, match:class ^(firefox)$, match:title ^(About Mozilla Firefox)$"
    "float true, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$"
    "float true, match:class ^(firefox)$, match:title ^(Firefox — Sharing Indicator)$"
    "float true, match:class ^(firefox)$, match:title ^(Extension:.*)"
    "float true, match:class ^(firefox)$, match:title ^$"

    # Firefox: Explicitly tile main browser windows
    "tile true, match:class ^(firefox)$, match:title ^(.*(Mozilla Firefox|Private Browsing))$"

    # GTK: Common dialog windows (About, Preferences, Settings)
    "float true, match:title ^(About|Preferences|Settings)(.*)$"

    # GTK: File chooser dialogs
    "float true, match:title ^(Open File|Save File|Save As|Select Folder|Choose|File Chooser|Open Folder)(.*)$"
    "size 900 700, match:title ^(Open File|Save File|Save As|Select Folder)(.*)$"

    # GTK: File manager and archive windows
    "float true, match:class ^(file-roller|org.gnome.FileRoller)$"
    "float true, match:title ^(Archive Manager)(.*)$"

    # GTK: Common dialog utilities
    "float true, match:class ^(zenity|yad|file-chooser|dialog)$"

    # Center all floating windows (popups, dialogs, etc.)
    "center true, match:float true"
  ];
}
