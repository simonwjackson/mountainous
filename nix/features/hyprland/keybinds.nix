# Hyprland keybindings configuration
{
  config,
  lib,
  pkgs,
  inputs,
}: let
  dictationEnabled = config.mountainous.dictation.enable or false;

  brightnessSync = pkgs.callPackage ../../packages/brightness-sync {};
  dictationPackage = pkgs.callPackage ../../packages/dictation {};
  scaleAdjust = pkgs.callPackage ../../packages/scale-adjust {};
  splitToggle = pkgs.callPackage ../../packages/split-toggle {};
  workspaceCycler = pkgs.callPackage ../../packages/workspace-cycler {inherit inputs;};

  dictationBin = "${dictationPackage}/bin/dictation";

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

  # Screenshot tools
  grim = "${pkgs.grim}/bin/grim";
  slurp = "${pkgs.slurp}/bin/slurp";
  satty = "${pkgs.satty}/bin/satty";
  wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  screenshotDir = "$HOME/Pictures/Screenshots";
  screenshotFile = ''$(${date} +"%Y-%m-%dT%H:%M:%S").png'';

  keybinds =
    {
      # Switch workspaces with mainMod + [0-9]
      "$mainMod, 1" = {
        kind = "bind";
        action = "workspace, 1";
      };
      "$mainMod, 2" = {
        kind = "bind";
        action = "workspace, 2";
      };
      "$mainMod, 3" = {
        kind = "bind";
        action = "workspace, 3";
      };
      "$mainMod, 4" = {
        kind = "bind";
        action = "workspace, 4";
      };
      "$mainMod, 5" = {
        kind = "bind";
        action = "workspace, 5";
      };
      "$mainMod, 6" = {
        kind = "bind";
        action = "workspace, 6";
      };
      "$mainMod, 7" = {
        kind = "bind";
        action = "workspace, 7";
      };
      "$mainMod, 8" = {
        kind = "bind";
        action = "workspace, 8";
      };
      "$mainMod, 9" = {
        kind = "bind";
        action = "workspace, 9";
      };
      "$mainMod, 0" = {
        kind = "bind";
        action = "workspace, 10";
      };

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      "$mainMod SHIFT, 1" = {
        kind = "bind";
        action = "movetoworkspace, 1";
      };
      "$mainMod SHIFT, 2" = {
        kind = "bind";
        action = "movetoworkspace, 2";
      };
      "$mainMod SHIFT, 3" = {
        kind = "bind";
        action = "movetoworkspace, 3";
      };
      "$mainMod SHIFT, 4" = {
        kind = "bind";
        action = "movetoworkspace, 4";
      };
      "$mainMod SHIFT, 5" = {
        kind = "bind";
        action = "movetoworkspace, 5";
      };
      "$mainMod SHIFT, 6" = {
        kind = "bind";
        action = "movetoworkspace, 6";
      };
      "$mainMod SHIFT, 7" = {
        kind = "bind";
        action = "movetoworkspace, 7";
      };
      "$mainMod SHIFT, 8" = {
        kind = "bind";
        action = "movetoworkspace, 8";
      };
      "$mainMod SHIFT, 9" = {
        kind = "bind";
        action = "movetoworkspace, 9";
      };
      "$mainMod SHIFT, 0" = {
        kind = "bind";
        action = "movetoworkspace, 10";
      };

      "$mainMod, D" = {
        kind = "bind";
        action = "togglespecialworkspace, magic";
      };
      "$mainMod, M" = {
        kind = "bind";
        action = "exec, hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.fullscreen' | ${pkgs.gnugrep}/bin/grep -q '2' && ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 0 || ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 1";
      };
      "$mainMod SHIFT, E" = {
        kind = "bind";
        action = "exec, ${kitty}";
      };
      "$mainMod, A" = {
        kind = "bind";
        action = "layoutmsg, swapwithmaster";
      };
      # For Android
      "$mainMod, F1" = {
        kind = "bind";
        action = "layoutmsg, swapwithmaster";
      };
      "$mainMod SHIFT, A" = {
        kind = "bind";
        action = "exec, ${workspaceCycler}/bin/workspaceCycler";
      };

      "$mainMod, P" = {
        kind = "bind";
        action = "exec, ${pkgs.hyprpicker}/bin/hyprpicker -a";
      };
      "$mainMod, W" = {
        kind = "bind";
        action = "exec, ${hyprctl} clients | grep -iq 'class: firefox' && ${hyprctl} dispatch focuswindow 'class:^(firefox)$' || ${firefox}";
      };
      "$mainMod, C" = {
        kind = "bind";
        action = "killactive,";
      };
      "$mainMod SHIFT, C" = {
        kind = "bind";
        action = "exec, ${hyprctl} activewindow -j | ${jq} '.pid' | ${xargs} -r kill -9";
      };
      # "$mainMod, F" reserved for nested Sway fullscreen toggle
      "$mainMod, V" = {
        kind = "bind";
        action = "togglefloating,";
      };
      "$mainMod SHIFT, Tab" = {
        kind = "bind";
        action = "cyclenext";
      };
      "$mainMod, Tab" = {
        kind = "bind";
        action = "cyclenext, -1";
      };
      "$mainMod SHIFT, M" = {
        kind = "bind";
        action = "fullscreen, 0";
      };
      "$mainMod, H" = {
        kind = "bind";
        action = "movefocus, l";
      };
      "$mainMod, J" = {
        kind = "bind";
        action = "movefocus, d";
      };
      "$mainMod, K" = {
        kind = "bind";
        action = "movefocus, u";
      };
      "$mainMod, L" = {
        kind = "bind";
        action = "movefocus, r";
      };
      "$mainMod, SPACE" = {
        kind = "bind";
        action = "exec, ${walker}";
      };
      "$mainMod CTRL, SPACE" = {
        kind = "bind";
        action = "exec, ${walker} --modules windows";
      };
      "$mainMod SHIFT, left" = {
        kind = "bind";
        action = "resizeactive, -20 0";
      };
      "$mainMod SHIFT, right" = {
        kind = "bind";
        action = "resizeactive, 20 0";
      };
      "$mainMod SHIFT, up" = {
        kind = "bind";
        action = "resizeactive, 0 -20";
      };
      "$mainMod SHIFT, down" = {
        kind = "bind";
        action = "resizeactive, 0 20";
      };
      "$mainMod, left" = {
        kind = "bind";
        action = "swapwindow, l";
      };
      "$mainMod, right" = {
        kind = "bind";
        action = "swapwindow, r";
      };
      "$mainMod, up" = {
        kind = "bind";
        action = "swapwindow, u";
      };
      "$mainMod, down" = {
        kind = "bind";
        action = "swapwindow, d";
      };
      "$mainMod, equal" = {
        kind = "bind";
        action = "exec, ${splitToggle}/bin/split-toggle";
      };

      # Screenshots - Region select → Satty → save
      "$mainMod, G" = {
        kind = "bind";
        action = ''exec, ${mkdir} -p ${screenshotDir} && ${grim} -g "$(${slurp})" - | ${satty} --filename - --output-filename "${screenshotDir}/${screenshotFile}"'';
      };

      # Screenshots - Active window → Satty → save
      "$mainMod SHIFT, G" = {
        kind = "bind";
        action = ''exec, ${mkdir} -p ${screenshotDir} && ${grim} -g "$(${hyprctl} activewindow -j | ${jq} -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | ${satty} --filename - --output-filename "${screenshotDir}/${screenshotFile}"'';
      };

      # Screenshots - Region select → Satty → save → copy file PATH to clipboard (for opencode)
      "$mainMod CTRL, G" = {
        kind = "bind";
        action = ''exec, FILE="${screenshotDir}/$(${date} +"%Y-%m-%dT%H:%M:%S").png" && ${mkdir} -p ${screenshotDir} && ${grim} -g "$(${slurp})" - | ${satty} --filename - --output-filename "$FILE" && echo -n "$FILE" | ${wlCopy} && ${notifySend} "Screenshot" "Path copied: $FILE"'';
      };

      ",XF86AudioRaiseVolume" = {
        kind = "bindel";
        action = "exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      };
      ",XF86AudioLowerVolume" = {
        kind = "bindel";
        action = "exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      };
      ",XF86AudioMute" = {
        kind = "bindel";
        action = "exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };
      ",XF86AudioMicMute" = {
        kind = "bindel";
        action = "exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      };
      ",XF86MonBrightnessUp" = {
        kind = "bindel";
        action = "exec, ${brightnessSync}/bin/brightness-extended up 1";
      };
      ",XF86MonBrightnessDown" = {
        kind = "bindel";
        action = "exec, ${brightnessSync}/bin/brightness-extended down 1";
      };

      # Monitor scaling controls
      "$mainMod SHIFT, plus" = {
        kind = "bindel";
        action = "exec, ${scaleAdjust}/bin/scale-adjust up all";
      };
      "$mainMod SHIFT, equal" = {
        kind = "bindel";
        action = "exec, ${scaleAdjust}/bin/scale-adjust up all";
      };
      "$mainMod SHIFT, minus" = {
        kind = "bindel";
        action = "exec, ${scaleAdjust}/bin/scale-adjust down all";
      };

      ", XF86AudioNext" = {
        kind = "bindl";
        action = "exec, ${playerctl} next";
      };
      ", XF86AudioPause" = {
        kind = "bindl";
        action = "exec, ${playerctl} play-pause";
      };
      ", XF86AudioPlay" = {
        kind = "bindl";
        action = "exec, ${playerctl} play-pause";
      };
      ", XF86AudioPrev" = {
        kind = "bindl";
        action = "exec, ${playerctl} previous";
      };

      "$mainMod, mouse:272" = {
        kind = "bindm";
        action = "movewindow";
      };
      "$mainMod, mouse:273" = {
        kind = "bindm";
        action = "resizewindow";
      };
    }
    // lib.optionalAttrs dictationEnabled {
      "$mainMod, S" = {
        kind = "bind";
        action = "exec, ${dictationBin}";
      };
      "$mainMod SHIFT, S" = {
        kind = "bind";
        action = "exec, ${dictationBin} --return";
      };
    };

  renderKeybinds = kind:
    lib.mapAttrsToList (
      combo: spec: "${combo}, ${spec.action}"
    ) (lib.filterAttrs (_: spec: spec.kind == kind) keybinds);
in {
  "$terminal" = "${kitty}";
  "$fileManager" = "${kitty} -- ${lf}";
  "$mainMod" = "SUPER";

  inherit keybinds;

  bind = renderKeybinds "bind";
  bindel = renderKeybinds "bindel";
  bindl = renderKeybinds "bindl";
  bindm = renderKeybinds "bindm";
}
