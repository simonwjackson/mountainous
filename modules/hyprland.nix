# The desktop: Hyprland shaped to Kamoi.
#
# Kamoi (~/code/sandbox/irori) tiles the web on Android: one page per window,
# a master pane and a stack, on an ordered strip of workspaces. Its README is
# the product manual and the only source for what follows.
#
# Hyprland is the right base because Kamoi's model is master-and-stack with a
# bounded capacity per workspace. Everything Kamoi asks for that a scrollable
# compositor cannot do is a first-class call here.
#
# The config is Lua, not hyprland.conf. Hyprland 0.56 reads both and prefers
# hyprland.lua; 0.56 also shows this on every launch of a .conf:
#
#   src/i18n/Engine.cpp:254
#     "You are using the .conf config format, support for which will be
#      removed in Hyprland 0.57."
#
# Every call below was read out of 0.56.2's own source rather than a wiki:
#
#   hl.dsp tree                 config/lua/bindings/LuaBindingsDispatchers.cpp
#   hl.dsp.focus{last=true}     -> dsp_focusCurrentOrLast
#   window.fullscreen mode      "fullscreen"|"maximized", action toggle/set/unset
#   window.resize keep_aspect_ratio  -> dsp_mouseResize, shape preserved
#   hl.gesture fingers 2..9     config/ConfigManager.cpp handleGesture
#   overall shape               example/hyprland.lua, shipped with 0.56.2
{
  nixos.modules.desktop =
    { pkgs, ... }:
    let
      # Kamoi's interface scale: one control that resizes the whole UI.
      #
      # This walks a ladder instead of adding a delta. Hyprland refuses any
      # scale that does not divide the panel into whole pixels:
      #
      #   Monitor.cpp:996
      #     "Invalid scale passed to monitor, {} failed to find a clean divisor"
      #
      # Every rung below divides 2880x1800 exactly:
      #   1.0  -> 2880x1800    1.6 -> 1800x1125
      #   1.2  -> 2400x1500    1.8 -> 1600x1000
      #   1.25 -> 2304x1440    2.0 -> 1440x900
      #   1.5  -> 1920x1200
      hypr-scale = pkgs.writeShellApplication {
        name = "hypr-scale";
        runtimeInputs = [
          pkgs.jq
          pkgs.gawk
        ];
        text = ''
          LADDER=(1.0 1.2 1.25 1.5 1.6 1.8 2.0)
          DEFAULT=1.5

          mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
          name=$(printf '%s' "$mon" | jq -r '.name')
          cur=$(printf '%s' "$mon" | jq -r '.scale')
          w=$(printf '%s' "$mon" | jq -r '.width')
          h=$(printf '%s' "$mon" | jq -r '.height')
          rr=$(printf '%s' "$mon" | jq -r '.refreshRate | . * 1000 | round / 1000')
          x=$(printf '%s' "$mon" | jq -r '.x')
          y=$(printf '%s' "$mon" | jq -r '.y')

          apply() {
            hyprctl keyword monitor "$name,''${w}x''${h}@''${rr},''${x}x''${y},$1"
          }

          # Nearest rung to the live value; the compositor may hold something
          # that is not exactly on the ladder.
          idx=0
          best=99
          for i in "''${!LADDER[@]}"; do
            d=$(awk -v a="''${LADDER[$i]}" -v b="$cur" 'BEGIN { d = a - b; if (d < 0) d = -d; print d }')
            if awk -v d="$d" -v b="$best" 'BEGIN { exit !(d < b) }'; then
              best=$d
              idx=$i
            fi
          done

          last=$(( ''${#LADDER[@]} - 1 ))
          case "''${1:-}" in
            up)    idx=$(( idx + 1 )); [ "$idx" -gt "$last" ] && idx=$last ;;
            down)  idx=$(( idx - 1 )); [ "$idx" -lt 0 ] && idx=0 ;;
            reset) apply "$DEFAULT"; exit 0 ;;
            get)   echo "$cur"; exit 0 ;;
            *)     echo "usage: hypr-scale up|down|reset|get" >&2; exit 2 ;;
          esac

          apply "''${LADDER[$idx]}"
        '';
      };

      # Kamoi zen mode: the same single window, inside a margin, so the page
      # reads as a column rather than a wall. Kamoi's defaults are 12% of the
      # width each side and 5% of the height top and bottom, stored as shares
      # so one setting reads the same in both orientations. Computed from the
      # live logical size for that reason.
      hypr-zen = pkgs.writeShellApplication {
        name = "hypr-zen";
        runtimeInputs = [
          pkgs.jq
          pkgs.gawk
        ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-zen"
          NORMAL_GAPS=8   # must match general.gaps_out in hyprland.lua

          if [ -e "$state" ]; then
            rm -f "$state"
            hyprctl keyword general:gaps_out "$NORMAL_GAPS"
            hyprctl dispatch fullscreen 0
            exit 0
          fi

          mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
          lw=$(printf '%s' "$mon" | jq -r '(.width / .scale) | round')
          lh=$(printf '%s' "$mon" | jq -r '(.height / .scale) | round')
          side=$(awk -v w="$lw" 'BEGIN { printf "%d", w * 0.12 }')
          vert=$(awk -v h="$lh" 'BEGIN { printf "%d", h * 0.05 }')

          touch "$state"
          hyprctl keyword general:gaps_out "''${vert},''${side},''${vert},''${side}"
          hyprctl dispatch fullscreen 1
        '';
      };

      # Kamoi Meta+G toggles the horizontal split between even and golden
      # ratios. `layoutmsg mfact` sets the focused workspace's ratio, which is
      # not the master:mfact option, so the state cannot be read back.
      hypr-split = pkgs.writeShellApplication {
        name = "hypr-split";
        runtimeInputs = [ ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-split-golden"
          if [ -e "$state" ]; then
            rm -f "$state"
            hyprctl dispatch layoutmsg "mfact exact 0.5"
          else
            touch "$state"
            hyprctl dispatch layoutmsg "mfact exact 0.61803"
          fi
        '';
      };
    in
    {
      programs.hyprland.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      };

      security.pam.services.greetd.enableGnomeKeyring = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
      security.rtkit.enable = true;

      xdg.portal.enable = true;

      environment.systemPackages = with pkgs; [
        alacritty
        fuzzel
        grim
        slurp
        wl-clipboard
        playerctl
        jq
        adwaita-icon-theme # without a cursor theme Hyprland falls back badly
        hypr-scale
        hypr-zen
        hypr-split
      ];

      hjem.users.simon.files.".config/hypr/hyprland.lua".text = ''
        -- Kamoi on a desktop. See modules/hyprland.nix for provenance.

        local mod = "SUPER"

        --------------------------------------------------------------------
        -- MONITOR
        --------------------------------------------------------------------
        -- Samsung Galaxy Book3 Pro 360: 2880x1800 OLED across 340x220mm,
        -- about 215 PPI, 120Hz. Scale 1.5 gives a logical 1920x1200.
        hl.monitor({
            output   = "eDP-1",
            mode     = "2880x1800@120",
            position = "0x0",
            scale    = "1.5",
        })

        hl.env("XCURSOR_THEME", "Adwaita")
        hl.env("XCURSOR_SIZE", "24")
        hl.env("HYPRCURSOR_SIZE", "24")

        --------------------------------------------------------------------
        -- LOOK AND FEEL
        --------------------------------------------------------------------
        hl.config({
            general = {
                -- Kamoi's window gap default is 8dp, sitting between the
                -- visible windows. gaps_in is per window edge, so 4 gives 8
                -- between two windows.
                gaps_in  = 4,
                gaps_out = 8,

                -- Kamoi: "Windows carry no border. The black gap separates
                -- them, and the pointer says which window is live."
                border_size = 0,

                -- The whole reason for Hyprland over a scrollable compositor.
                layout = "master",

                resize_on_border = false,
            },

            decoration = {
                -- Kamoi draws no rounded corners, no blur, no shadows.
                rounding = 0,
                blur   = { enabled = false },
                shadow = { enabled = false },
            },

            animations = { enabled = true },

            master = {
                -- Even split by default; Meta+G toggles to golden.
                mfact       = 0.5,
                -- Kamoi's master sits on one side; Meta+Shift+G mirrors it.
                orientation = "left",
                -- A new window joins the stack rather than displacing master.
                new_status  = "slave",
            },

            input = {
                kb_layout          = "us",
                numlock_by_default = true,
                -- Kamoi: "Moving into a window focuses it."
                follow_mouse       = 1,
                touchpad = {
                    natural_scroll       = true,
                    disable_while_typing = true,
                },
            },

            misc = {
                disable_hyprland_logo   = true,
                disable_splash_rendering = true,
                force_default_wallpaper = 0,
                -- Kamoi: "The gap always shows the black backdrop."
                background_color        = 0x000000,
            },
        })

        hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
        hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "quick" })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "quick" })
        hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "quick" })

        --------------------------------------------------------------------
        -- GESTURES
        --------------------------------------------------------------------
        -- Kamoi zooms out to the workspace strip on a three-finger swipe, and
        -- leaves one and two fingers to the page so carousels and maps keep
        -- them.
        hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

        --------------------------------------------------------------------
        -- GROUP 1: layout and windows
        --------------------------------------------------------------------
        hl.bind(mod .. " + N", hl.dsp.exec_cmd("alacritty"))
        hl.bind(mod .. " + C", hl.dsp.window.close())

        -- Kamoi Meta+1/2/3 set the page capacity: one fullscreen window, two
        -- columns, or a master pane with two stacked windows. Hyprland derives
        -- the shape from the window count, so 1 forces the single-window view
        -- and 2/3 set the split those capacities use.
        --
        -- "maximized" fills the usable area and leaves room for a bar;
        -- "fullscreen" below covers everything. That is exactly Kamoi's
        -- distinction between capacity 1 and monocle mode.
        hl.bind(mod .. " + 1", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        hl.bind(mod .. " + 2", hl.dsp.layout("mfact exact 0.5"))
        hl.bind(mod .. " + 3", hl.dsp.layout("mfact exact 0.61803"))

        -- Even versus golden split.
        hl.bind(mod .. " + G", hl.dsp.exec_cmd("hypr-split"))

        -- Kamoi Meta+Shift+G mirrors the workspace, so the master pane holds
        -- the other end of the split.
        hl.bind(mod .. " + SHIFT + G", hl.dsp.layout("orientationcycle left right"))

        -- Kamoi: "Meta+Enter promotes the focused window into the master pane;
        -- pressed from the master it pulls up the stack window you left, so
        -- the pane flips between two."
        hl.bind(mod .. " + Return", hl.dsp.layout("swapwithmaster master"))

        -- Monocle fills the screen outright; zen puts it inside a margin.
        hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
        hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("hypr-zen"))

        hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }))
        -- Kamoi Meta+Shift+F makes a floater sticky, so it follows you along
        -- the workspace strip.
        hl.bind(mod .. " + SHIFT + F", hl.dsp.window.pin())

        hl.bind(mod .. " + CTRL + equal", hl.dsp.window.resize({ x =  80, y =  50, relative = true }))
        hl.bind(mod .. " + CTRL + minus", hl.dsp.window.resize({ x = -80, y = -50, relative = true }))

        -- Kamoi: "A floater takes three pointer drags, all with Meta held.
        -- Left-drag carries the whole window. Right-drag sizes it. Meta+Shift
        -- and right-drag scale it instead: the window keeps its shape, only
        -- its size changes."
        hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
        hl.bind(mod .. " + SHIFT + mouse:273", hl.dsp.window.resize({ keep_aspect_ratio = true }), { mouse = true })

        --------------------------------------------------------------------
        -- GROUP 2: navigation and switching
        --------------------------------------------------------------------
        local dirs = { H = "left", L = "right", K = "up", J = "down" }
        for key, dir in pairs(dirs) do
            hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
            hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
        end
        for _, dir in ipairs({ "left", "right", "up", "down" }) do
            hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
        end

        -- Kamoi Meta+Tab, quick press: straight back to the window you came
        -- from, with nothing drawn.
        hl.bind(mod .. " + Tab", hl.dsp.focus({ last = true }))

        hl.bind(mod .. " + bracketleft",  hl.dsp.layout("cycleprev"))
        hl.bind(mod .. " + bracketright", hl.dsp.layout("cyclenext"))

        -- The workspace strip.
        hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
        hl.bind(mod .. " + Page_Up",   hl.dsp.focus({ workspace = "e-1" }))
        hl.bind(mod .. " + CTRL + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
        hl.bind(mod .. " + CTRL + Page_Up",   hl.dsp.window.move({ workspace = "e-1" }))
        hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
        hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

        --------------------------------------------------------------------
        -- GROUP 3: scale
        --------------------------------------------------------------------
        -- The interface scale sizes everything. Per-application zoom is the
        -- application's own business, which is why Ctrl+= is absent.
        hl.bind(mod .. " + equal", hl.dsp.exec_cmd("hypr-scale up"))
        hl.bind(mod .. " + minus", hl.dsp.exec_cmd("hypr-scale down"))
        hl.bind(mod .. " + 0",     hl.dsp.exec_cmd("hypr-scale reset"))
        hl.bind(mod .. " + SHIFT + mouse_up",   hl.dsp.exec_cmd("hypr-scale up"))
        hl.bind(mod .. " + SHIFT + mouse_down", hl.dsp.exec_cmd("hypr-scale down"))

        --------------------------------------------------------------------
        -- Placeholder for Kamoi's omni bar, which is not built yet. fuzzel
        -- launches applications and nothing else. Kamoi reserves F1 for the
        -- bar so a keyboard with no Escape key can still reach Settings.
        --------------------------------------------------------------------
        hl.bind(mod .. " + Space", hl.dsp.exec_cmd("fuzzel"))
        hl.bind("F1", hl.dsp.exec_cmd("fuzzel"))

        -- Kamoi Meta+S captures the screen, Meta+Shift+S the focused window.
        -- Kamoi opens both for markup; that surface is not built yet.
        hl.bind(mod .. " + S", hl.dsp.exec_cmd(
            "mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
        hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(
            "mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))

        --------------------------------------------------------------------
        -- Hardware keys
        --------------------------------------------------------------------
        hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --class=backlight set +10%"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 10%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
        hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
        hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"), { locked = true })
        hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"), { locked = true })

        hl.bind(mod .. " + SHIFT + P", hl.dsp.dpms({ action = "off" }))
        hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
      '';
    };
}
