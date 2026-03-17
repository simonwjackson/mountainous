{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkOption types;

  hyprlandEnabled = osConfig.mountainous.features.hyprland.enable or false;
  hostName = osConfig.networking.hostName or "";
  isYuki = hostName == "yuki";

  sharedHyprlandKeybindsConfig = import ./keybinds.nix {
    inherit config lib pkgs osConfig;
    inputs = {};
  };
  sharedHyprlandKeybinds = sharedHyprlandKeybindsConfig.keybinds;
  homeHyprlandKeybinds = {
    "$mainMod, Return" = {
      kind = "bind";
      action = "exec, $terminal";
    };
    "$mainMod, N" = {
      kind = "bind";
      action = "exec, ${pkgs.writeShellScript "darkman-toggle" ''
        current=$(${pkgs.systemd}/bin/busctl --user get-property nl.whynothugo.darkman /nl/whynothugo/darkman nl.whynothugo.darkman Mode 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' | tr -d '"')
        if [ "$current" = "dark" ]; then
          next="light"
        else
          next="dark"
        fi
        ${pkgs.systemd}/bin/busctl --user set-property nl.whynothugo.darkman /nl/whynothugo/darkman nl.whynothugo.darkman Mode s "$next"
      ''}";
    };
    "$mainMod CTRL, E" = {
      kind = "bind";
      action = "exit,";
    };
    ", Print" = {
      kind = "bind";
      action = ''exec, grim -g "$(slurp)" - | wl-copy'';
    };
  };
  finalHyprlandKeybinds = lib.filterAttrs (_: spec: spec != null) (
    sharedHyprlandKeybinds // homeHyprlandKeybinds // config.mountainous.hyprland.keybinds
  );
  renderHyprlandKeybinds = kind:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (combo: spec: "      ${kind} = ${combo}, ${spec.action}") (
        lib.filterAttrs (_: spec: spec.kind == kind) finalHyprlandKeybinds
      )
    );

  ironbarBar = {
    position = "top";
    height = 32;
    start = [
      {
        type = "workspaces";
        favorites = [
          "1"
          "2"
          "3"
          "4"
          "5"
        ];
      }
    ];
    center = [
      {
        type = "clock";
        format = "%-I:%M";
      }
    ];
    end = [
      {
        type = "custom";
        class = "codexbar";
        bar = [
          {
            type = "button";
            label = "{{120000:codexbar-claude}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "vertical";
            widgets = [
              {
                type = "label";
                label = "{{120000:codexbar-claude-detail}}";
              }
            ];
          }
        ];
      }
      {
        type = "custom";
        class = "codexbar";
        bar = [
          {
            type = "button";
            label = "{{120000:codexbar-codex}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "vertical";
            widgets = [
              {
                type = "label";
                label = "{{120000:codexbar-codex-detail}}";
              }
            ];
          }
        ];
      }
      {
        type = "custom";
        class = "codexbar";
        bar = [
          {
            type = "button";
            label = "{{3600000:codexbar-oci}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "vertical";
            widgets = [
              {
                type = "label";
                label = "{{3600000:codexbar-oci-detail}}";
              }
            ];
          }
        ];
      }
      {
        type = "volume";
        format = "{icon} {percentage}%";
      }
      {
        type = "network_manager";
        icon_size = 18;
      }
      {
        type = "battery";
        format = "{percentage}%";
        thresholds = {
          warning = 20;
          critical = 5;
        };
      }
      {
        type = "tray";
        icon_size = 16;
      }
    ];
  };
  ironbarConfig =
    if isYuki
    then {
      start = null;
      center = null;
      end = null;
      monitors = {
        "eDP-1" = ironbarBar;
        "DP-1" = ironbarBar;
      };
    }
    else ironbarBar;
in {
  options.mountainous.hyprland.extraSettings = mkOption {
    type = types.attrsOf types.anything;
    default = {};
    description = "Extra Hyprland settings (composable from multiple home-manager modules)";
  };

  options.mountainous.hyprland.keybinds = mkOption {
    type = types.attrsOf (
      types.nullOr (
        types.submodule {
          options = {
            kind = mkOption {
              type = types.enum [
                "bind"
                "bindel"
                "bindl"
                "bindm"
              ];
              description = "Which Hyprland bind keyword to render for this key chord.";
            };

            action = mkOption {
              type = types.str;
              description = "The dispatcher and arguments, e.g. `exec, kitty`.";
            };
          };
        }
      )
    );
    default = {};
    description = ''
      Per-host Hyprland keybinding overrides keyed by key chord.

      Use the same key to replace a shared binding, or set it to `null` to remove it.
    '';
  };

  config = lib.mkIf hyprlandEnabled {
    # NOTE: Do NOT use gtk.enable here. The desktop theme system
    # (presets/desktop/home.nix) manages gtk settings.ini as mutable files
    # so darkman can switch themes at runtime. HM's gtk module would create
    # immutable symlinks for the same files, causing "clobber" errors on
    # every subsequent activation.
    home.packages = with pkgs; [
      adwaita-icon-theme
      ironbar
      tofi
      wl-clipboard
      grim
      slurp
      brightnessctl
      pavucontrol
      networkmanagerapplet
    ];

    xdg.configFile = {
      "hypr/hyprland.conf".text = ''
              $mod = ${sharedHyprlandKeybindsConfig."$mainMod"}
              $mainMod = ${sharedHyprlandKeybindsConfig."$mainMod"}
              $terminal = ${sharedHyprlandKeybindsConfig."$terminal"}
              $fileManager = ${sharedHyprlandKeybindsConfig."$fileManager"}
              $menu = tofi-drun

              ${lib.optionalString (!isYuki) ''
          monitor = eDP-1, 2880x1800@60, 0x0, 1, transform, 2
                monitor = eDP-2, 2880x1800@60, 0x1800, 1''}

              ${lib.optionalString isYuki ''
          # Yuki-specific visual baseline
          # -----------------------------
          # Keep the desktop background as a plain solid black. That fits the dual-OLED
          # hardware well and avoids distracting default wallpaper or splash visuals.
          misc:force_default_wallpaper = 0
          misc:background_color = 0x000000

          # Yuki-specific single-window layout
          # ---------------------------------
          # When a workspace only has one tiled or fullscreen window, let the app use the
          # whole panel instead of keeping outer gaps and rounded corners.
          workspace = w[tv1], gapsout:0, gapsin:0
          workspace = f[1], gapsout:0, gapsin:0
          windowrule = border_size 0, match:float false, match:workspace w[tv1]
          windowrule = rounding 0, match:float false, match:workspace w[tv1]
          windowrule = border_size 0, match:float false, match:workspace f[1]
          windowrule = rounding 0, match:float false, match:workspace f[1]''}

              # Host-specific Hyprland quirks live in separately managed files so laptop-specific
              # tweaks do not get buried in this generic user config.
              ${lib.optionalString isYuki ''source = ${
            config.xdg.configFile."hypr/yuki-quirks.conf".source
          }''}

              # Source yuki's generated monitor layout after the bootstrap workaround file so
              # HyprDynamicMonitors can override the static internal-only layout once it has
              # written ~/.config/hypr/monitors.conf.
              ${lib.optionalString isYuki ''source = ~/.config/hypr/monitors.conf''}

              exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP=Hyprland
              exec-once = systemctl --user start graphical-session.target
              exec-once = nm-applet --indicator
              exec-once = ironbar
              exec-once = sh -c 'sleep 2 && touch "$XDG_RUNTIME_DIR/ironbar-dictation.css" && ${pkgs.ironbar}/bin/ironbar style load-css "$XDG_RUNTIME_DIR/ironbar-dictation.css"'

              env = XCURSOR_SIZE,24
              env = NIXOS_OZONE_WL,1

              input {
                kb_layout = us
                follow_mouse = 1
                touchpad {
                  natural_scroll = false
                  tap-to-click = true
                  disable_while_typing = true
                }
              }

              general {
                gaps_in = 4
                gaps_out = 8
                border_size = 0
                layout = dwindle
              }

              decoration {
                rounding = 8
              }

              animations {
                enabled = false
              }

              dwindle {
                pseudotile = true
                preserve_split = true
              }

              misc {
                disable_hyprland_logo = true
                force_default_wallpaper = 0
                background_color = 0x000000
              }

        ${renderHyprlandKeybinds "bind"}
        ${lib.optionalString (renderHyprlandKeybinds "bindel" != "") ''

          ${renderHyprlandKeybinds "bindel"}''}
        ${lib.optionalString (renderHyprlandKeybinds "bindl" != "") ''

          ${renderHyprlandKeybinds "bindl"}''}
        ${lib.optionalString (renderHyprlandKeybinds "bindm" != "") ''

          ${renderHyprlandKeybinds "bindm"}''}
      '';

      "ironbar/config.json".text = builtins.toJSON ironbarConfig;

      "ironbar/style.css".text = ''
        * {
          font-family: monospace, "Symbols Nerd Font";
          font-size: 12px;
        }

        .background {
          background-color: transparent;
          color: #ffffff;
        }

        #bar {
          padding: 0 6px;
        }

        .widget {
          margin: 0 2px;
          background: transparent;
        }

        .workspaces .item,
        .clock,
        .volume,
        .network_manager,
        .battery,
        .tray,
        .script,
        button {
          padding: 0 8px;
          background: transparent;
          box-shadow: none;
        }

        .codexbar button {
          padding: 0 6px;
        }

        .popup-codexbar {
          padding: 12px 16px;
          font-family: monospace;
          font-size: 12px;
        }

        .popup {
          background-color: @theme_bg_color;
          color: @theme_fg_color;
          border: 1px solid @borders;
          border-radius: 8px;
          padding: 8px;
        }
      '';
    };
  };
}
