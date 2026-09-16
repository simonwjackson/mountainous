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
    { config, pkgs, ... }:
    let
      hyprPkg = config.programs.hyprland.package;

      # Under a Lua config, hyprctl changes shape and the legacy forms die
      # quietly. Verified on the machine:
      #
      #   hyprctl keyword monitor ...
      #     -> "keyword can't work with non-legacy parsers. Use eval."
      #   hyprctl dispatch layoutmsg "mfact exact 0.5"
      #     -> error: [string "return hl.dispatch(layoutmsg mfact exact 0.5)"]
      #        ')' expected near 'mfact'
      #
      # So `dispatch` now evaluates its argument as Lua, and `keyword` is
      # refused outright in favour of `eval`. Worse, hyprctl still exits 0
      # after printing those errors, so a broken helper looks like a working
      # one. Everything below uses the Lua forms.
      # Kamoi's interface scale: one control that resizes the whole UI, held
      # apart from per-application zoom.
      #
      # Hyprland quantises scale to 1/120 and then demands whole logical
      # pixels. From output/Monitor.cpp:
      #
      #   float    searchScale = std::round(m_scale * 120.0);
      #   double   scaleZero   = searchScale / 120.0;
      #   Vector2D logicalZero = m_pixelSize / scaleZero;
      #   if (logicalZero == logicalZero.round()) m_scale = scaleZero;
      #
      # So a legal scale is N/120 where both pw*120/N and ph*120/N are whole,
      # which means N divides 120 * gcd(pw, ph). For this 2880x1800 panel that
      # is 43200, giving 11 legal scales between 1.0 and 2.0.
      #
      # Miss the set and Hyprland does not fail outright: it hunts +/-1/120 up
      # to 90 steps, and on success raises a red notification naming the scale
      # it substituted. Working off the exact set avoids that notification.
      #
      # The ladder is computed from the live mode rather than written down, so
      # it stays correct on whatever monitor this stick is plugged into. Fine
      # steps move one rung, coarse steps three, which is how Kamoi's
      # Meta+scroll and Ctrl+Meta+scroll differ.
      #
      # The 1/120 rounding also absorbs decimal truncation: 160/120 prints as
      # 1.333333, and Hyprland multiplies by 120 and rounds straight back.
      hypr-scale = pkgs.writeShellApplication {
        name = "hypr-scale";
        runtimeInputs = [
          pkgs.jq
          pkgs.gawk
          hyprPkg # hyprctl; do not rely on inheriting it from the session
        ];
        text = ''
          MIN=0.8
          MAX=3.0
          DEFAULT=1.5
          COARSE_RUNGS=3

          case "''${1:-}" in
            up)        rungs=$COARSE_RUNGS ;;
            down)      rungs=-$COARSE_RUNGS ;;
            fine-up)   rungs=1 ;;
            fine-down) rungs=-1 ;;
            # Quoted because `reset` and `list` are also real commands; a
            # bare word there trips SC2209 as a likely missing $(...).
            # (Keep "shellcheck" off the start of a comment line: that is
            # its directive syntax and it errors with SC1124 inside a case.)
            reset)     rungs="reset" ;;
            get)       rungs="get" ;;
            list)      rungs="list" ;;
            *) echo "usage: hypr-scale up|down|fine-up|fine-down|reset|get|list" >&2; exit 2 ;;
          esac

          mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
          name=$(printf '%s' "$mon" | jq -r '.name')
          cur=$(printf '%s' "$mon" | jq -r '.scale')
          pw=$(printf '%s' "$mon" | jq -r '.width')
          ph=$(printf '%s' "$mon" | jq -r '.height')
          rr=$(printf '%s' "$mon" | jq -r '.refreshRate | . * 1000 | round / 1000')
          x=$(printf '%s' "$mon" | jq -r '.x')
          y=$(printf '%s' "$mon" | jq -r '.y')

          [ "$rungs" = get ] && { echo "$cur"; exit 0; }

          apply() {
            hyprctl eval "hl.monitor({ output = \"$name\", mode = \"''${pw}x''${ph}@''${rr}\", position = \"''${x}x''${y}\", scale = \"$1\" })"
          }

          [ "$rungs" = reset ] && { apply "$DEFAULT"; exit 0; }

          ladder() {
            awk -v cur="$cur" -v n="$1" -v pw="$pw" -v ph="$ph" \
                -v lo="$MIN" -v hi="$MAX" -v mode="$2" '
              function gcd(a, b) { while (b) { t = b; b = a % b; a = t } return a }
              BEGIN {
                # Legal scales are N/120 for N dividing 120*gcd(pw, ph).
                M = 120 * gcd(pw, ph)
                count = 0
                for (k = int(lo * 120 + 0.5); k <= int(hi * 120 + 0.5); k++)
                  if (M % k == 0) L[++count] = k

                if (mode == "list") {
                  for (i = 1; i <= count; i++)
                    printf "%.4f -> %dx%d\n", L[i]/120, pw*120/L[i], ph*120/L[i]
                  exit
                }

                # Nearest rung to the live value, which may sit off-ladder.
                curN = cur * 120
                bi = 1; bd = 1e9
                for (i = 1; i <= count; i++) {
                  d = L[i] - curN; if (d < 0) d = -d
                  if (d < bd) { bd = d; bi = i }
                }

                i = bi + n
                if (i < 1) i = 1
                if (i > count) i = count
                printf "%.6f", L[i] / 120
              }'
          }

          [ "$rungs" = list ] && { ladder 0 list; exit 0; }

          apply "$(ladder "$rungs" step)"
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
          hyprPkg
        ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-zen"
          NORMAL_GAPS=8   # must match general.gaps_out in hyprland.lua

          if [ -e "$state" ]; then
            rm -f "$state"
            hyprctl eval "hl.config({ general = { gaps_out = $NORMAL_GAPS } })"
            hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" })'
            exit 0
          fi

          mon=$(hyprctl -j monitors | jq -r 'map(select(.focused))[0]')
          lw=$(printf '%s' "$mon" | jq -r '(.width / .scale) | round')
          lh=$(printf '%s' "$mon" | jq -r '(.height / .scale) | round')
          side=$(awk -v w="$lw" 'BEGIN { printf "%d", w * 0.12 }')
          vert=$(awk -v h="$lh" 'BEGIN { printf "%d", h * 0.05 }')

          touch "$state"
          # A comma string is the legacy form. Lua's css_gap type refuses it:
          #   "css_gap type requires an integer or a table with optional
          #    top, right, bottom, left fields"
          hyprctl eval "hl.config({ general = { gaps_out = { top = ''${vert}, right = ''${side}, bottom = ''${vert}, left = ''${side} } } })"
          hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })'
        '';
      };

      # Kamoi Meta+G toggles the horizontal split between even and golden
      # ratios. `layoutmsg mfact` sets the focused workspace's ratio, which is
      # not the master:mfact option, so the state cannot be read back.
      hypr-split = pkgs.writeShellApplication {
        name = "hypr-split";
        runtimeInputs = [ hyprPkg ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-split-golden"
          if [ -e "$state" ]; then
            rm -f "$state"
            hyprctl dispatch 'hl.dsp.layout("mfact exact 0.5")'
          else
            touch "$state"
            hyprctl dispatch 'hl.dsp.layout("mfact exact 0.61803")'
          fi
        '';
      };
    in
    {
      programs.hyprland.enable = true;

      services.greetd = {
        enable = true;
        # start-hyprland, not Hyprland. It is "a binary to properly start
        # Hyprland via a watchdog process", and it is what Hyprland's own
        # session entry runs:
        #
        #   share/wayland-sessions/hyprland.desktop
        #     Exec=.../bin/start-hyprland
        #
        # Launching the compositor directly makes it warn on every start:
        #   i18n/Engine.cpp:253  TXT_KEY_NOTIF_NO_WATCHDOG
        #   "Hyprland was started without start-hyprland. This is strongly
        #    discouraged unless you are in a debugging environment."
        #
        # Deliberately unqualified. start-hyprland resolves "Hyprland"
        # through PATH, and NixOS puts /run/wrappers/bin first, where
        # programs/wayland/hyprland.nix installs a wrapper carrying
        # cap_sys_nice+ep for realtime scheduling. An absolute store path
        # would execute the uncapped binary instead.
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      };

      security.pam.services.greetd.enableGnomeKeyring = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
      security.rtkit.enable = true;

      xdg.portal = {
        enable = true;
        # Without a backend the portal never activates, and the journal shows:
        #   "Could not activate remote peer 'org.freedesktop.portal.Desktop'"
        # The hyprland backend serves screencast and screenshot; the gtk one
        # serves file pickers, which the hyprland backend does not implement.
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = "*";
      };

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
        -- Capacity is a CAP on how many windows the page holds, not a split
        -- ratio. Hyprland has no such cap, so this keeps the number per
        -- workspace and pushes the overflow onto the next one, which is what
        -- Kamoi's ordered strip does.
        --
        -- The shapes then fall out of the master layout by themselves: one
        -- window fills the screen, two give two columns, three give a master
        -- with two stacked beside it. No mfact is set here; that is Meta+G.
        --
        -- hl.bind takes a plain Lua function as well as a dispatcher object:
        --   "bind: dispatcher must be a dispatcher (e.g. hl.dsp.window.close())
        --    or a lua function"
        local DEFAULT_CAPACITY = 1
        local capacity = {}

        local function cap_of(id)
            return capacity[id] or DEFAULT_CAPACITY
        end

        local function tiled_windows(ws)
            local out = {}
            for _, w in ipairs(ws:get_windows()) do
                -- Floating windows sit outside the tiled page, so Kamoi's
                -- capacity does not count them.
                if not w.floating then out[#out + 1] = w end
            end
            return out
        end

        -- Move everything past the cap onto the next workspace, newest first,
        -- so the master end of the page keeps the windows already there.
        local function enforce(ws)
            if ws == nil or ws.special then return end
            local wins = tiled_windows(ws)
            local over = #wins - cap_of(ws.id)
            if over <= 0 then return end

            for i = #wins, #wins - over + 1, -1 do
                hl.dispatch(hl.dsp.focus({ window = "address:" .. wins[i].address }))
                hl.dispatch(hl.dsp.window.move({ workspace = ws.id + 1 }))
            end
        end

        local function set_capacity(n)
            return function()
                local ws = hl.get_active_workspace()
                if ws == nil or ws.special then return end
                capacity[ws.id] = n
                enforce(ws)
            end
        end

        hl.bind(mod .. " + 1", set_capacity(1))
        hl.bind(mod .. " + 2", set_capacity(2))
        hl.bind(mod .. " + 3", set_capacity(3))

        -- A new window over the cap goes straight to the next page. Moving a
        -- window raises no open event, so this cannot cascade: if the next
        -- page is also full, the window simply stays there.
        hl.on("window.open", function(win)
            if win == nil or win.floating then return end
            enforce(win.workspace)
        end)

        -- Closing the last window on a page should leave the page, not strand
        -- you on it.
        --
        -- Hyprland destroys an empty workspace only when you walk away from
        -- it, so the focused one is the single empty workspace that can
        -- exist. Measured on this machine:
        --
        --   after closing everything   known=[3] occupied=[] EMPTY=[3]
        --   after visiting ws 7        known=[7] occupied=[] EMPTY=[7]
        --   after leaving ws 7         known=[1] occupied=[] EMPTY=[1]
        --
        -- Kamoi's strip has no dead pages: a page exists while it holds
        -- something. Stepping away on the last close gives the same result,
        -- because Hyprland then collects the workspace itself.
        local function nearest_occupied(from)
            local best = nil
            for _, w in ipairs(hl.get_workspaces()) do
                if w.id > 0 and w.id ~= from and w.windows > 0 then
                    if best == nil then
                        best = w.id
                    else
                        local d, bd = math.abs(w.id - from), math.abs(best - from)
                        -- On a tie, step back along the strip rather than
                        -- forward, so closing a window walks you towards the
                        -- work you already had open.
                        if d < bd or (d == bd and w.id < best) then best = w.id end
                    end
                end
            end
            return best
        end

        local function leave_if_empty()
            local ws = hl.get_active_workspace()
            if ws == nil or ws.special then return end
            if ws.windows > 0 then return end
            local target = nearest_occupied(ws.id)
            -- No target means this was the last window anywhere. Stay put:
            -- an empty desktop is a real state, not a page to flee.
            if target ~= nil then
                hl.dispatch(hl.dsp.focus({ workspace = target }))
            end
        end

        hl.on("window.destroy", leave_if_empty)
        -- A window moved off the page empties it just as a close does.
        hl.on("workspace.active", leave_if_empty)

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

        -- Kamoi reaches the workspace strip with a three-finger swipe, and
        -- gives Meta+scroll to the interface scale instead. Meta+scroll is
        -- deliberately NOT bound to workspaces here for that reason.

        -- Kamoi: "Meta+Enter promotes the focused window"; jumping to the
        -- master pane without swapping is the other half of that pair.
        hl.bind(mod .. " + SHIFT + Return", hl.dsp.layout("focusmaster master"))

        -- Kamoi's capacity is a cap on how many windows a page holds. Hyprland
        -- has no such cap, so these add and remove windows in the master area,
        -- which is the nearest real control over how the page is divided.
        hl.bind(mod .. " + A",         hl.dsp.layout("addmaster"))
        hl.bind(mod .. " + SHIFT + A", hl.dsp.layout("removemaster"))

        --------------------------------------------------------------------
        -- GROUP 3: scale
        --------------------------------------------------------------------
        -- The interface scale sizes everything. Per-application zoom is the
        -- application's own business, which is why Ctrl+= is absent.
        hl.bind(mod .. " + equal", hl.dsp.exec_cmd("hypr-scale up"))
        hl.bind(mod .. " + minus", hl.dsp.exec_cmd("hypr-scale down"))
        hl.bind(mod .. " + 0",     hl.dsp.exec_cmd("hypr-scale reset"))

        -- Kamoi: "Meta+scroll: preview the complete interface scale; release
        -- Meta to save it" and "Ctrl+Meta+scroll: adjust the interface scale
        -- in smaller steps". Each detent commits on its own here, because
        -- Hyprland has no press-and-hold bind to preview against.
        hl.bind(mod .. " + mouse_up",          hl.dsp.exec_cmd("hypr-scale up"))
        hl.bind(mod .. " + mouse_down",        hl.dsp.exec_cmd("hypr-scale down"))
        hl.bind(mod .. " + CTRL + mouse_up",   hl.dsp.exec_cmd("hypr-scale fine-up"))
        hl.bind(mod .. " + CTRL + mouse_down", hl.dsp.exec_cmd("hypr-scale fine-down"))

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

        -- Kamoi Meta+I hides the top bar and the dock together for immersive
        -- browsing. The bars are Quickshell; see modules/bars.nix.
        hl.bind(mod .. " + I", hl.dsp.exec_cmd("qs -c cairn ipc call chrome toggle"))

        hl.bind(mod .. " + SHIFT + P", hl.dsp.dpms({ action = "off" }))
        hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
      '';
    };
}
