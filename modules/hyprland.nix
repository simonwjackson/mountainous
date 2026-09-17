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

      # The session, not just the compositor.
      #
      # Hyprland publishes its own environment to the systemd user manager and
      # withdraws it on exit. Both command lines are literals in the 0.56.2
      # binary:
      #
      #   systemctl --user import-environment DISPLAY WAYLAND_DISPLAY
      #     HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP
      #     QT_QPA_PLATFORMTHEME PATH XDG_DATA_DIRS
      #   systemctl --user unset-environment <the same list>
      #
      # It never starts graphical-session.target, and neither does
      # start-hyprland. The string "graphical-session" appears in neither
      # binary. So a unit with WantedBy=graphical-session.target never ran at
      # login. The bars only ever appeared because a person started them by
      # hand, and they stayed dead after the compositor restarted.
      #
      # graphical-session.target sets RefuseManualStart=yes, so no script can
      # start it directly. Verified on hiyori. A compositor target that binds to
      # it is the supported route: systemd starts a refused target when another
      # unit depends on it. RefuseManualStop is no, so exit can tear the whole
      # session down through it.
      start-mountainous = pkgs.writeShellApplication {
        name = "start-mountainous";
        # hyprPkg is deliberately absent. writeShellApplication prepends
        # runtimeInputs to PATH, which would make start-hyprland resolve
        # "Hyprland" to the bare store binary instead of the wrapper in
        # /run/wrappers/bin that carries cap_sys_nice+ep.
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
        ];
        text = ''
          # A compositor that died took its units down with it and may have
          # burned their restart budget. start refuses a unit still marked
          # failed, so clear the slate before the new session begins.
          systemctl --user reset-failed || true

          # Hyprland publishes the environment only once it is up, so watch for
          # the signature rather than race it. Bash pattern matching, to keep
          # grep out of PATH and out of this script's closure.
          (
            for _ in {1..100}; do
              if [[ "$(systemctl --user show-environment)" == *HYPRLAND_INSTANCE_SIGNATURE=* ]]; then
                systemctl --user start hyprland-session.target
                exit 0
              fi
              sleep 0.1
            done
            echo "start-mountainous: Hyprland never published HYPRLAND_INSTANCE_SIGNATURE" >&2
            exit 1
          ) &

          # Unqualified, so PATH finds /run/wrappers/bin/Hyprland first. See
          # the note on runtimeInputs above.
          rc=0
          start-hyprland "$@" || rc=$?

          # Stop the session so its services exit cleanly. Without this they
          # restart against a compositor that is gone, fail five times, and
          # stay failed.
          systemctl --user stop graphical-session.target || true
          exit "$rc"
        '';
      };
    in
    {
      programs.hyprland.enable = true;

      # The bridge to graphical-session.target. start-mountainous starts this one;
      # systemd pulls in graphical-session.target because this target binds to
      # it, which is legal where a manual start is not.
      systemd.user.targets.hyprland-session = {
        description = "Hyprland session";
        documentation = [ "man:systemd.special(7)" ];
        bindsTo = [ "graphical-session.target" ];
        wants = [ "graphical-session-pre.target" ];
        after = [ "graphical-session-pre.target" ];
      };

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
        #
        # start-mountainous wraps start-hyprland to reach graphical-session.target.
        # It calls start-hyprland unqualified for the reason above.
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${start-mountainous}/bin/start-mountainous";
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
                -- A deliberate departure from Kamoi, which draws square
                -- corners. Blur and shadows stay off: those cost a pass over
                -- every frame, and a radius costs nothing but a shader
                -- branch already present.
                --
                -- 6 was chosen by photographing one window's corner at 0, 4,
                -- 6, 8 and 12 on this panel rather than guessing. 4 is
                -- invisible at 215 PPI, 12 reads as decorative. 6 is 9
                -- physical pixels at scale 1.5, about a millimetre: enough to
                -- look intended, not enough to notice.
                rounding = 6,
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

                -- Load-bearing for the terminal overlay, not a preference:
                -- it is what hides the special workspace once its last
                -- window unmaps, and that is the first step in retiring the
                -- workspace so the next SUPER+T builds a fresh terminal. Set
                -- rather than inherited, because the default was not read
                -- out of the source and the overlay must not depend on it.
                -- See the TERMINAL OVERLAY section below.
                close_special_on_empty  = true,
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

        -- Forward declaration: enforce() finishes by compacting the strip, and
        -- compact() is defined further down next to the page lifecycle.
        local compact

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

        -- The first id past the end of the strip.
        local function end_of_strip()
            local maxid = 0
            for _, w in ipairs(hl.get_workspaces()) do
                if w.id > 0 and w.windows > 0 and w.id > maxid then maxid = w.id end
            end
            return maxid + 1
        end

        -- Move everything past the cap off the page, newest first, so the
        -- master end keeps the windows already there.
        --
        -- Each overflow window gets a fresh page at the end of the strip, not
        -- ws.id + 1. Two reasons, both found by testing: id+1 may already be
        -- full, and an overflow landing on a full page raises no event, so
        -- nothing would ever correct it. Compaction then pulls the new page
        -- back next to its neighbours, so "the end" is only where it lands,
        -- not where it stays.
        local function enforce(ws)
            if ws == nil or ws.special then return end
            local wins = tiled_windows(ws)
            local over = #wins - cap_of(ws.id)
            if over <= 0 then return end

            local target = end_of_strip()
            for i = #wins, #wins - over + 1, -1 do
                hl.dispatch(hl.dsp.focus({ window = "address:" .. wins[i].address }))
                hl.dispatch(hl.dsp.window.move({ workspace = target }))
                target = target + 1
            end
            compact()
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

        -- Keep the strip numbered 1..N with no holes.
        --
        -- Pages are positions on Kamoi's strip, not names, so a gap in the
        -- numbering is meaningless. Left alone the ids only climb: creating
        -- and collecting pages walked this machine up to 21..23 in one
        -- session of testing.
        --
        -- Renaming in ascending order cannot collide. For a sorted list of
        -- distinct positive ids, occ[i] >= i always, so by the time occ[i] is
        -- renamed to i every smaller page already holds 1..i-1, and every
        -- page not yet renamed holds occ[j] > occ[i] >= i. Target i is free.
        local compacting = false

        compact = function()
            -- hl.dispatch runs synchronously and change_id raises workspace
            -- events, so without this guard compact() re-enters itself.
            if compacting then return end
            compacting = true

            local occ = {}
            for _, w in ipairs(hl.get_workspaces()) do
                -- Only pages that hold something. A focused-but-empty page is
                -- about to be collected, and special workspaces are not part
                -- of the strip at all.
                if w.id > 0 and w.windows > 0 then occ[#occ + 1] = w.id end
            end
            table.sort(occ)

            for i, id in ipairs(occ) do
                if id ~= i then
                    hl.dispatch(hl.dsp.workspace.change_id({ workspace = id, id = i }))
                end
            end

            compacting = false
        end

        hl.on("workspace.created", compact)
        hl.on("workspace.removed", compact)

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
        -- GROUP 4: the terminal overlay
        --
        -- One terminal, on a special workspace, shown and hidden with
        -- SUPER+T. It sits outside Kamoi's strip on purpose: a page is
        -- somewhere you navigate to, and this is something you drop in front
        -- of whichever page you are on, then dismiss. SUPER+N still opens
        -- ordinary terminals as windows on the strip; this is not that.
        --
        -- The spawn happens on the key press, not on a compositor event.
        -- That is the whole design, and it is a correction.
        --
        -- This was first written as a workspace rule:
        --
        --   hl.workspace_rule({ workspace        = "special:term",
        --                       on_created_empty = "alacritty" })
        --
        -- On hiyori that spawned terminals without stopping. The reasoning
        -- behind it was traced through 0.56.2's source and every statement
        -- in it is still true: togglespecialworkspace creates the workspace
        -- with isEmpty defaulting to true (WorkspaceState.hpp:28), init()
        -- runs on-created-empty for that flag with no special-workspace
        -- exclusion (Workspace.cpp:68), and close_special_on_empty retires
        -- the workspace when its last window unmaps (Window.cpp:730).
        --
        -- The conclusion drawn from those facts was the wrong part. "The
        -- workspace is created once per press" is not something the source
        -- says anywhere. on-created-empty fires on workspace creation, so
        -- anything that recreates the workspace spawns another terminal,
        -- and a terminal that arrives late enough to find the workspace
        -- rebuilt spawns the next one. Nothing in that chain needs a person.
        --
        -- So the spawn is no longer reachable from a compositor event. It
        -- runs on the bind, behind a check for the terminal it is about to
        -- create. A runaway needs a spawn that causes a spawn, and a keybind
        -- cannot press itself.
        --
        -- term_window() searches every workspace rather than the overlay
        -- alone, so a terminal that lands somewhere unexpected is still
        -- found and still not duplicated. That makes the worst remaining
        -- failure bounded and visible: if the spawn rule does not place the
        -- window, one stray terminal appears on the current page and SUPER+T
        -- toggles an empty overlay. Wrong, but finite, and it stops.
        --
        -- The dock and the omni bar need no change to ignore it. Both filter
        -- on workspace.id > 0 (modules/bars.nix, modules/omni.nix) and
        -- special workspace ids are negative, so the overlay stays out of
        -- the window list and out of the strip.
        --
        -- Deliberately NOT scaled down into a floating panel.
        -- master.special_scale_factor is still a live config name in 0.56.2
        -- and the binary still carries the string, but MasterAlgorithm.cpp
        -- never reads it. Setting it would read as a decision and do
        -- nothing. The overlay fills the page instead.
        --
        -- The overlay runs herdr, not a shell. herdr keeps its sessions on a
        -- server that outlives the client, so closing this window costs
        -- nothing and the next launch attaches to the same work. `herdr` with
        -- no arguments is the documented form for that; from its own --help:
        --
        --   herdr    Launch or attach to the persistent session
        --
        -- So the overlay never has to decide between creating and resuming,
        -- and two launches cannot produce two sessions. See modules/herdr.nix.
        --
        -- DEFERRED: the machines. herdr reaches other hosts with `herdr
        -- machine add <ssh-target>`, which needs those hosts reachable over
        -- SSH from here. This system does not set that up yet, so the overlay
        -- currently shows local work only. Nothing below changes when it
        -- does: the machines become part of herdr's own state, not the
        -- compositor's.
        --------------------------------------------------------------------
        local TERM_WS    = "term"
        local TERM_CLASS = "mountainous-term"
        local TERM_CMD   = "alacritty --class " .. TERM_CLASS .. " -e herdr"

        -- Sized against the monitor, centred, and floating.
        --
        -- 61.8% is the same golden split hypr-split gives SUPER+G, used here
        -- on both axes so the overlay reads as one object over the page
        -- rather than a pane of it. The page stays visible around all four
        -- edges, which is what makes it legible as a thing on top.
        --
        -- Percentages, not pixels, so the rule is a function of whatever
        -- monitor the stick is plugged into rather than of this panel. A
        -- floating window is required for the size to mean anything: a tiled
        -- window is sized by the layout, and the rule would be ignored.
        hl.window_rule({
            name   = "term-overlay",
            match  = { class = TERM_CLASS },
            float  = true,
            size   = "61.8% 61.8%",
            center = true,
        })

        -- The overlay's terminal, wherever it currently is, or nil. Matching
        -- on class rather than on workspace is deliberate: a terminal that
        -- missed the overlay must still count as existing, or the bind would
        -- build a new one on every press.
        local function term_window()
            for _, w in ipairs(hl.get_windows()) do
                if w.class == TERM_CLASS then return w end
            end
            return nil
        end

        hl.bind(mod .. " + T", function()
            if term_window() == nil then
                hl.exec_cmd(TERM_CMD, { workspace = "special:" .. TERM_WS .. " silent" })
            end
            hl.dispatch(hl.dsp.workspace.toggle_special(TERM_WS))
        end)

        --------------------------------------------------------------------
        -- The omni bar. See modules/omni.nix.
        --
        -- Kamoi reserves F1 for it so a keyboard with no Escape key can
        -- still reach Settings, and binds a second chord straight into the
        -- window list.
        --
        -- On P rather than Kamoi's Space: held Space is now SUPER itself, so
        -- SUPER+Space would mean holding one key to modify the same key.
        --------------------------------------------------------------------
        hl.bind(mod .. " + P",         hl.dsp.exec_cmd("qs -c mountainous ipc call omni toggle"))
        hl.bind("F1",                  hl.dsp.exec_cmd("qs -c mountainous ipc call omni toggle"))
        hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("qs -c mountainous ipc call omni gotowindow"))

        -- Kamoi's Ctrl+L shows the address bar. Here it opens the omni bar in
        -- navigate mode, which is the address bar an --app window never built.
        --
        -- Bound conditionally on purpose: Ctrl+L belongs to whatever is
        -- focused, and a terminal clears its screen with it. Only a Chromium
        -- window has an address to change, and Chromium always names those
        -- chrome-<host>__-Default, so the class is the test. Anything else has
        -- the key handed straight back to it.
        hl.bind("CTRL + L", function()
            local w = hl.get_active_window()
            if w == nil then return end
            if (w.class or ""):match("^chrome%-") then
                hl.dispatch(hl.dsp.exec_cmd("qs -c mountainous ipc call omni navigate"))
            else
                hl.dispatch(hl.dsp.pass({ window = "address:" .. w.address }))
            end
        end)

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
        hl.bind(mod .. " + I", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome toggle"))

        -- O for off. Moved off SHIFT+P, which the omni bar's window list now
        -- owns.
        hl.bind(mod .. " + SHIFT + O", hl.dsp.dpms({ action = "off" }))
        hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
      '';
    };
}
