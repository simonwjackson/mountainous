# Hyprland keybindings configuration
{
  lib,
  pkgs,
  inputs,
}: let
  # Tool paths
  date = "${pkgs.coreutils}/bin/date";
  grep = "${pkgs.gnugrep}/bin/grep";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  xargs = "${pkgs.findutils}/bin/xargs";
  firefox = "${pkgs.firefox}/bin/firefox";
  kitty = "${pkgs.kitty}/bin/kitty";
  lf = "${pkgs.lf}/bin/lf";
  walker = "${pkgs.walker}/bin/walker";
in {
  "$terminal" = "${kitty}";
  "$fileManager" = "${kitty} -- ${lf}";
  "$mainMod" = "SUPER";
  "$screenshotTmpl" = ''/home/simonwjackson/Pictures/$(${date} +"%Y-%m-%dT%H:%M:%S").png'';

  bind = [
    # Switch workspaces with mainMod + [0-9]
    "$mainMod, 1, workspace, 1"
    "$mainMod, 2, workspace, 2"
    "$mainMod, 3, workspace, 3"
    "$mainMod, 4, workspace, 4"
    "$mainMod, 5, workspace, 5"
    "$mainMod, 6, workspace, 6"
    "$mainMod, 7, workspace, 7"
    "$mainMod, 8, workspace, 8"
    "$mainMod, 9, workspace, 9"
    "$mainMod, 0, workspace, 10"

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    "$mainMod SHIFT, 1, movetoworkspace, 1"
    "$mainMod SHIFT, 2, movetoworkspace, 2"
    "$mainMod SHIFT, 3, movetoworkspace, 3"
    "$mainMod SHIFT, 4, movetoworkspace, 4"
    "$mainMod SHIFT, 5, movetoworkspace, 5"
    "$mainMod SHIFT, 6, movetoworkspace, 6"
    "$mainMod SHIFT, 7, movetoworkspace, 7"
    "$mainMod SHIFT, 8, movetoworkspace, 8"
    "$mainMod SHIFT, 9, movetoworkspace, 9"
    "$mainMod SHIFT, 0, movetoworkspace, 10"

    "$mainMod, D, togglespecialworkspace, magic"
    "$mainMod, M, exec, hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.fullscreen' | ${pkgs.gnugrep}/bin/grep -q '2' && ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 0 || ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 1"
    "$mainMod SHIFT, E, exec, ${kitty}"
    "$mainMod, A, layoutmsg, swapwithmaster"
    # For Android
    "$mainMod, F1, layoutmsg, swapwithmaster"
    "$mainMod SHIFT, A, exec, ${pkgs.workspace-cycler}/bin/workspaceCycler"

    "$mainMod, P, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a"
    "$mainMod, W, exec, ${hyprctl} clients | grep -iq 'class: firefox' && ${hyprctl} dispatch focuswindow 'class:^(firefox)$' || ${firefox}"
    "$mainMod, O, exec, ${hyprctl} clients | ${grep} -iq 'class: obsidian' && ${hyprctl} dispatch focuswindow 'class:^(obsidian)$' || ${pkgs.obsidian}/bin/obsidian"
    "$mainMod, C, killactive,"
    "$mainMod SHIFT, C, exec, ${hyprctl} activewindow -j | ${jq} '.pid' | ${xargs} -r kill -9"
    "$mainMod, F, exec, $fileManager"
    "$mainMod, V, togglefloating,"
    "$mainMod SHIFT, Tab, cyclenext"
    "$mainMod, Tab, cyclenext, -1"
    "$mainMod SHIFT, M, fullscreen, 0"
    "$mainMod, H, movefocus, l"
    "$mainMod, J, movefocus, d"
    "$mainMod, K, movefocus, u"
    "$mainMod, L, movefocus, r"
    "$mainMod, SPACE, exec, ${walker}"
    "$mainMod CTRL, SPACE, exec, ${walker} --modules windows"
    "$mainMod SHIFT, left, resizeactive, -20 0"
    "$mainMod SHIFT, right, resizeactive, 20 0"
    "$mainMod SHIFT, up, resizeactive, 0 -20"
    "$mainMod SHIFT, down, resizeactive, 0 20"
    "$mainMod, left, swapwindow, l"
    "$mainMod, right, swapwindow, r"
    "$mainMod, up, swapwindow, u"
    "$mainMod, down, swapwindow, d"
    "$mainMod, S, exec, ${pkgs.dictation}/bin/dictation"
    "$mainMod SHIFT, S, movetoworkspace, special:magic"
    "$mainMod, N, exec, ${pkgs.darkmode-toggle}/bin/darkmode-toggle"
    "$mainMod, equal, exec, ${pkgs.split-toggle}/bin/split-toggle"
  ];

  bindel = [
    ",XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
    ",XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ",XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ",XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    ",XF86MonBrightnessUp, exec, ${pkgs.brightness-sync}/bin/brightness-sync up 5"
    ",XF86MonBrightnessDown, exec, ${pkgs.brightness-sync}/bin/brightness-sync down 5"

    # Monitor scaling controls
    "$mainMod SHIFT, plus, exec, ${pkgs.scale-adjust}/bin/scale-adjust up all"
    "$mainMod SHIFT, equal, exec, ${pkgs.scale-adjust}/bin/scale-adjust up all"
    "$mainMod SHIFT, minus, exec, ${pkgs.scale-adjust}/bin/scale-adjust down all"
  ];

  bindl = [
    ", XF86AudioNext, exec, ${playerctl} next"
    ", XF86AudioPause, exec, ${playerctl} play-pause"
    ", XF86AudioPlay, exec, ${playerctl} play-pause"
    ", XF86AudioPrev, exec, ${playerctl} previous"
  ];

  bindm = [
    "$mainMod, mouse:272, movewindow"
    "$mainMod, mouse:273, resizewindow"
  ];
}
