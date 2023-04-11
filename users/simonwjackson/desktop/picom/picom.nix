{
  shadow = true;
  no-dnd-shadow = true;
  no-dock-shadow = true;
  clear-shadow = true;
  shadow-radius = 50;
  shadow-offset-x = -30;
  shadow-offset-y = -30;
  shadow-opacity = 0.8;
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
}
