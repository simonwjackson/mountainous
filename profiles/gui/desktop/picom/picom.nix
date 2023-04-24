{
  backend = "glx";
  vsync = true;

  shadow = true;
  clear-shadow = true;
  no-dnd-shadow = true;
  no-dock-shadow = true;
  shadow-radius = 25;
  shadow-offset-x = -25;
  shadow-offset-y = -25;
  shadow-opacity = 0.25;
  shadow-exclude = [
    "class_g = 'Awesome'"
    "! name~=''"
    "name = 'Notification'"
    "name = 'Plank'"
    "name = 'Docky'"
    "name = 'Kupfer'"
    "name = 'xfce4-notifyd'"
    "name = 'cairo-dock'"
    "name *= 'compton'"
    "name *= 'Picom'"
    "_GTK_FRAME_EXTENTS@:c"
    "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
    "class_g = 'awesome'"
    "class_g = 'Xfce4-panel'"
  ];
  xinerama-shadow-crop = true;
}
