-- Kamoi on a desktop. See modules/hyprland.nix for provenance.

local mod = "SUPER"

--------------------------------------------------------------------
-- MONITOR
--------------------------------------------------------------------
-- Samsung Galaxy Book3 Pro 360: 2880x1800 OLED across 340x220mm,
-- about 215 PPI, 120Hz. Scale 1.5 gives a logical 1920x1200.
hl.monitor({
    output   = "eDP-1",
    mode     = "2880x1800@60",
    position = "0x0",
    scale    = "1.5",
})

-- YMK EM160TP-A, the portable 16-inch monitor: the same 2880x1800 across
-- the same 340x220mm as the panel. It sits above the panel at the panel's
-- scale, so both are a logical 1920x1200 and line up edge to edge.
-- Matched by description, because its DP-n name depends on the port.
hl.monitor({
    output   = "desc:YMK EM160TP-A 0x00000001",
    mode     = "preferred",
    position = "0x-1200",
    scale    = "1.5",
})

-- The hub can expose the same external panel twice. Keep both wires lit,
-- but only one desktop/workspace destination. eDP-1 is never a candidate.
require("duplicate-outputs").attach()

-- The pointer follows the desktop theme (modules/desktop-art.nix).
-- desktop-theme writes ~/.icons/Mountainous-cursors, a theme that only
-- inherits the current one, and runs `setcursor` on a switch. XCursor
-- clients name the stable alias, so even a process started before the
-- last switch loads the current cursors. Hyprland's own hyprcursor needs
-- the real name at login; it is read back from the alias.
local function cursor_theme()
    local file = io.open((os.getenv("HOME") or "") .. "/.icons/Mountainous-cursors/index.theme", "r")
    if file then
        for line in file:lines() do
            local name = line:match("^Inherits=(%S+)")
            if name then
                file:close()
                return name
            end
        end
        file:close()
    end
    return "Mountainous-platinum-cursors"
end
hl.env("XCURSOR_THEME", "Mountainous-cursors")
hl.env("HYPRCURSOR_THEME", cursor_theme())
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("NIXOS_OZONE_WL", "1")

--------------------------------------------------------------------
-- LOOK AND FEEL
--------------------------------------------------------------------
-- The master layout's starting split and side. Session restore compares a
-- saved page against these to decide whether the page needs changing.
local MASTER_RATIO = 0.5
local MASTER_SIDE  = "left"

-- The window edge outside Platinum. Under the Platinum desktop theme
-- titlebars.lua (below) gives windows a black hair and square corners
-- instead, and puts these back for every other theme.
local BORDER_SIZE = 0
local ROUNDING    = 6

hl.config({
    xwayland = {
        -- Prevent compositor bilinear scaling of any remaining X11 apps at
        -- fractional display scale.
        force_zero_scaling = true,
    },

    general = {
        -- Kamoi's window gap default is 8dp, sitting between the
        -- visible windows. gaps_in is per window edge, so 4 gives 8
        -- between two windows.
        gaps_in  = 4,
        gaps_out = 8,

        -- Kamoi: "Windows carry no border. The black gap separates
        -- them, and the pointer says which window is live."
        border_size = BORDER_SIZE,

        -- The whole reason for Hyprland over a scrollable compositor.
        layout = "master",

        resize_on_border = false,

        -- Do not wrap around within the current workspace when focus hits the edge.
        -- Enables cross-workspace directional navigation.
        no_focus_fallback = true,
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
        rounding = ROUNDING,
        blur   = { enabled = false },
        shadow = { enabled = false },
    },

    animations = { enabled = true },

    cursor = {
        -- Quickshell activates dock items through the foreign-toplevel
        -- protocol. Hyprland handles that request with CWindow::activate(),
        -- which otherwise warps the pointer to the activated window's centre.
        no_warps = true,
        -- desktop-theme owns the GNOME cursor-theme key; Hyprland would
        -- write the XCursor alias's name there on every load.
        sync_gsettings_theme = false,
    },

    master = {
        -- Even split by default; Meta+G toggles to golden.
        mfact       = MASTER_RATIO,
        -- Kamoi's master sits on one side; Meta+Shift+G mirrors it.
        orientation = MASTER_SIDE,
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
            tap_to_click         = false,
            tap_and_drag         = false,
            clickfinger_behavior = true,
        },
    },

    misc = {
        -- 0.56.2 ConfigValues.cpp:498. Permit a new lock after a locker crash.
        allow_session_lock_restore = true,
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

        -- A key press must be able to wake a panel that DPMS turned off.
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },
})

-- The session's motion. Under the Platinum and Windows 98 desktop themes
-- titlebars.lua (below) turns windows, fade and layers off on every parse
-- and theme change: those OSes cut, and the shell draws their own motion.
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
hl.bind(mod .. " + N", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + C", hl.dsp.window.close())

-- The page owns capacity, floating, gaps, defaults and strip lifecycle.
local page_layout = require("page-layout").attach()
for n = 1, 3 do
    local cap = n
    hl.bind(mod .. " + " .. n, function() page_layout.page("active", { cap = cap }) end)
end
hl.bind(mod .. " + bracketleft", function() page_layout.step_gap("active", -4) end)
hl.bind(mod .. " + bracketright", function() page_layout.step_gap("active", 4) end)

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

hl.bind(mod .. " + F", function() page_layout.toggle_floating("active") end)
hl.bind(mod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))
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
local function find_window_by(wins, comparator)
    if #wins == 0 then return nil end
    local best = wins[1]
    for i = 2, #wins do
        if comparator(wins[i], best) then best = wins[i] end
    end
    return best
end

-- Both stay on the current monitor. Hyprland's own directional focus
-- already crosses to the next monitor; these only take over when it found
-- no window, and then they walk this monitor's pages.
local function prev_occupied_workspace(here)
    local best = nil
    for _, w in ipairs(hl.get_workspaces()) do
        if w.id > 0 and w.id < here.id and w.windows > 0 and same_monitor(w, here) then
            if best == nil or w.id > best.id then best = w end
        end
    end
    return best
end

local function next_occupied_workspace(here)
    local best = nil
    for _, w in ipairs(hl.get_workspaces()) do
        if w.id > 0 and w.id > here.id and w.windows > 0 and same_monitor(w, here) then
            if best == nil or w.id < best.id then best = w end
        end
    end
    return best
end

local function move_focus(dir)
    local cur_win = hl.get_active_window()
    local ws = hl.get_active_workspace()
    if ws == nil or ws.special then return end

    if cur_win ~= nil then
        hl.dispatch(hl.dsp.focus({ direction = dir }))
        local after = hl.get_active_window()
        if after ~= nil and after.address ~= cur_win.address then
            return
        end
    end

    local target_ws = nil
    local select_target_window = nil

    if dir == "left" then
        target_ws = prev_occupied_workspace(ws)
        select_target_window = function(wins)
            return find_window_by(wins, function(a, b)
                if a.at.x ~= b.at.x then return a.at.x > b.at.x end
                return a.at.y < b.at.y
            end)
        end
    elseif dir == "right" then
        target_ws = next_occupied_workspace(ws)
        select_target_window = function(wins)
            return find_window_by(wins, function(a, b)
                if a.at.x ~= b.at.x then return a.at.x < b.at.x end
                return a.at.y < b.at.y
            end)
        end
    elseif dir == "up" then
        target_ws = prev_occupied_workspace(ws)
        select_target_window = function(wins)
            return find_window_by(wins, function(a, b)
                if a.at.y ~= b.at.y then return a.at.y > b.at.y end
                return a.at.x < b.at.x
            end)
        end
    elseif dir == "down" then
        target_ws = next_occupied_workspace(ws)
        select_target_window = function(wins)
            return find_window_by(wins, function(a, b)
                if a.at.y ~= b.at.y then return a.at.y < b.at.y end
                return a.at.x < b.at.x
            end)
        end
    end

    if target_ws == nil then return end

    local wins = tiled_windows(target_ws)
    local win_to_focus = select_target_window(wins)

    if win_to_focus ~= nil then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. win_to_focus.address }))
    else
        hl.dispatch(hl.dsp.focus({ workspace = target_ws.id }))
    end
end

local dirs = { H = "left", L = "right", K = "up", J = "down" }
for key, dir in pairs(dirs) do
    hl.bind(mod .. " + " .. key, function() move_focus(dir) end)
    hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, function() move_focus(dir) end)
end

-- Kamoi Meta+Tab, quick press: straight back to the window you came
-- from, with nothing drawn.
--
-- Held: with Super still down, each further Tab steps through the apps in
-- most recently used order on the Platinum Application menu, or through
-- the windows in Win98's Cool Switch box (Shift+Tab steps back), and
-- releasing Super switches to the one it is on. A repeat
-- timer watches for Super going up (hl.is_key_down), because a release
-- bind on Super_L would also fire after every other Super chord. Each
-- message carries the position and a rising number, so two qs processes
-- that arrive out of order cannot undo a commit (app-model.js accept()).
-- A theme without a cycle() ignores the messages; the quick press is the
-- same under every theme.
local app_cycle = nil
local app_cycle_seq = os.time() * 1000
local function app_cycle_send(action, position)
    app_cycle_seq = app_cycle_seq + 1
    hl.exec_cmd("qs -c mountainous ipc call chrome cycle " .. action .. " " .. position .. " " .. app_cycle_seq)
end
local function super_down()
    return hl.is_key_down("Super_L") or hl.is_key_down("Super_R")
end
local function app_cycle_end()
    if not app_cycle then return end
    local c = app_cycle
    app_cycle = nil
    c.watch:set_enabled(false)
    if c.stepped then app_cycle_send("commit", c.position) end
end
local function app_cycle_step(delta)
    if not app_cycle then
        hl.dispatch(hl.dsp.focus({ last = true }))
        if not super_down() then return end
        local c = { position = 1, stepped = false, started = os.time() }
        app_cycle = c
        c.watch = hl.timer(function()
            -- Super is up, or a lost release left the cycle open for a
            -- minute: end it.
            if app_cycle ~= c then return end
            if not super_down() or os.time() - c.started > 60 then app_cycle_end() end
        end, { timeout = 25, type = "repeat" })
        return
    end
    app_cycle.position = app_cycle.position + delta
    app_cycle.stepped = true
    app_cycle_send("step", app_cycle.position)
end
hl.bind(mod .. " + Tab", function() app_cycle_step(1) end)
hl.bind(mod .. " + SHIFT + Tab", function() app_cycle_step(-1) end)

hl.bind(mod .. " + bracketleft",  hl.dsp.layout("cycleprev"))
hl.bind(mod .. " + bracketright", hl.dsp.layout("cyclenext"))

-- The workspace strip. "m" walks the open pages of the focused monitor;
-- "e" would walk every monitor's pages and jump screens on the way
-- (helpers/MiscFunctions.cpp, onAllMonitors = in[0] == 'e'). With one
-- monitor the two are the same.
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + Page_Up",   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CTRL + Page_Down", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mod .. " + CTRL + Page_Up",   hl.dsp.window.move({ workspace = "m-1" }))

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
--                       on_created_empty = "ghostty" })
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
-- Ghostty uses the class as its GTK application ID, so it must contain a dot.
local TERM_CLASS = "io.github.simonwjackson.mountainous.term"
local TERM_CMD   = "ghostty --class=" .. TERM_CLASS .. " -e herdr"

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
    name  = "term-overlay",
    match = { class = TERM_CLASS },
    float = true,
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

-- Ghostty applies its initial GTK geometry after Hyprland's static size rule.
-- Resize one tick later, from the monitor's logical dimensions, so the 61.8%
-- contract remains intrinsic at every scale and the terminal cannot restore
-- its 800x600 default over it.
local term_resize_timers = {}
local function fit_term_overlay(win)
    if win == nil or win.class ~= TERM_CLASS then return end
    local address = win.address
    local timer
    timer = hl.timer(function()
        local current = nil
        for _, candidate in ipairs(hl.get_windows()) do
            if candidate.address == address then current = candidate; break end
        end
        if current ~= nil and current.monitor ~= nil then
            local monitor = current.monitor
            local width = math.floor(monitor.width / monitor.scale * 0.618 + 0.5)
            local height = math.floor(monitor.height / monitor.scale * 0.618 + 0.5)
            local selector = "address:" .. address
            hl.dispatch(hl.dsp.window.resize({
                x = width, y = height, window = selector,
            }))
            hl.dispatch(hl.dsp.window.center({ window = selector }))
        end
        term_resize_timers[address] = nil
    end, { timeout = 100, type = "oneshot" })
    term_resize_timers[address] = timer
end
hl.on("window.open", fit_term_overlay)

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

--------------------------------------------------------------------
-- Hold-to-talk dictation. See modules/dictation.nix.
--
-- Alt_R is the physical Right Alt key that Kanata leaves untouched. The
-- release binding ignores modifiers so releasing Right Alt still ends the
-- take when Shift was held for the send-Enter variant. Neither binding is
-- marked locked, so Hyprland blocks it while a session lock owns input.
-- Kanata's K+L chord emits the real Escape keysym. Right Alt is a modifier,
-- not a member of Hyprland's pressed non-modifier key set, so the Escape bind
-- checks the exact physical modifier. auto_consuming passes ordinary Escape
-- through and consumes only the dictation cancel gesture.
--------------------------------------------------------------------
hl.bind("Alt_R",         hl.dsp.exec_cmd("qs -c mountainous ipc call dictation press"))
hl.bind("SHIFT + Alt_R", hl.dsp.exec_cmd("qs -c mountainous ipc call dictation pressEnter"))
hl.bind("Alt_R",         hl.dsp.exec_cmd("qs -c mountainous ipc call dictation release"), { release = true, ignore_mods = true })
hl.bind("Escape", function()
    if not hl.is_key_down("Alt_R") then return { ok = false } end
    hl.exec_cmd("qs -c mountainous ipc call dictation cancel")
    return { ok = true }
end, { ignore_mods = true, auto_consuming = true })

--------------------------------------------------------------------
-- Appearance. See modules/theme.nix.
--
-- One command, and every layer that can follow changes with it: the
-- XDG portal republishes the color scheme for Chromium, GTK and Qt,
-- Ghostty follows the published desktop color scheme, and Quickshell reads
-- the state file the command writes.
--------------------------------------------------------------------
hl.bind(mod .. " + D", hl.dsp.exec_cmd("desktop-theme toggle"))

-- Separate face and verified runtime; do not send this to the desktop shell.
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("pyxamp ipc call pyxamp toggle"))

-- Lock. SUPER+L belongs to the H/J/K/L focus keys above, so the lock is
-- SUPER+Escape: hold Space (Super), then the K+L chord (Kanata's Escape;
-- the physical Escape key is dead on the base layer). The Alt_R Escape bind
-- above passes this through. Route all locks through hypridle.
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"))

-- Ctrl+L belongs to Go to Address / Open in Chromium, under both themes.
-- Normal windows report chromium-browser; --app and extension popups report
-- chrome-*. auto_consuming returns the original key to every other client
-- (not a synthetic pass), just like the conditional Ctrl+Escape below.
hl.bind("CTRL + L", function()
    local w = hl.get_active_window()
    local class = w and (w.class or ""):lower() or ""
    local normal = class == "chromium" or class == "chromium-browser"
    if (not normal and not class:match("^chrome%-")) or
        (normal and os.getenv("MOUNTAINOUS_BROWSER_INTEGRATION") == "0") then
        return { ok = false }
    end
    hl.exec_cmd("qs -c mountainous ipc call omni navigate")
    return { ok = true }
end, { auto_consuming = true })

-- Both captures open the same Satty markup surface. The helper owns output
-- naming, clipboard behavior, and focused-window geometry so the keybinds and
-- omni bar cannot drift into different screenshot workflows.
hl.bind(mod .. " + S", hl.dsp.exec_cmd("mountainous-screenshot screen"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("mountainous-screenshot window"))

--------------------------------------------------------------------
-- Hardware keys
--------------------------------------------------------------------
-- One level for every screen: the panel and each DDC/CI monitor move
-- together. See modules/brightness.nix.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("mountainous-brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("mountainous-brightness down"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
-- Pyxamp owns the follow policy and forwards to the observed native player.
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl --player=pyxamp play-pause"), { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl --player=pyxamp next"), { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl --player=pyxamp previous"), { locked = true })

-- Kamoi Meta+I hides the top bar and the dock together for immersive
-- browsing. The bars are Quickshell; see modules/bars.nix.
hl.bind(mod .. " + I", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome toggle"))

-- The Fleet window (Beszel's fleet health) and the glance space it shares
-- with Disks. Each desktop theme draws its own (Platinum's windoid and
-- focus layer; Win98's window above the tray and the Shut Down checker);
-- a theme without them ignores the calls.
hl.bind(mod .. " + B", hl.dsp.exec_cmd("qs -c mountainous ipc call fleet toggle"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs -c mountainous ipc call glance toggle"))

-- Top-bar keyboard access uses one mnemonic namespace. SUPER+O enters the
-- namespace, then B opens Bluetooth, W opens Wi-Fi, S opens Sound, L opens
-- Brightness, C opens Cloud, D opens Disks, F toggles the Fleet window, R
-- opens Remote builds on hosts that show them, or N opens Notifications
-- (Platinum and Win98; under another desktop theme N passes through as
-- before). The top bar or the tray shows the available keys while the
-- submap is active. Escape
-- or three seconds of inactivity cancels it.
local topbar_access_timer = nil
hl.bind(mod .. " + O", function()
    hl.dispatch(hl.dsp.submap("topbar-access"))
    hl.dispatch(hl.dsp.exec_cmd("qs -c mountainous ipc call chrome reveal"))

    if topbar_access_timer then
        topbar_access_timer:set_enabled(false)
    end
    topbar_access_timer = hl.timer(function()
        if hl.get_current_submap() == "topbar-access" then
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(hl.dsp.exec_cmd("qs -c mountainous ipc call chrome hide"))
        end
    end, { timeout = 3000, type = "oneshot" })
end)

-- Win98's Start key. While the Windows 98 desktop theme is active (see
-- modules/theme.nix: theme-name), Ctrl+Esc opens its Start menu; under any
-- other theme the keys go to the focused window as before. A lone Super is
-- not bound: Kanata's held Space is Super, so a lone Super release would
-- fire whenever a held Space times out without a chord.
local function desktop_theme_name()
    local dir = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
    local file = io.open(dir .. "/mountainous/theme-name", "r")
    if not file then return "platinum" end
    local name = (file:read("*l") or ""):match("^%s*(.-)%s*$")
    file:close()
    return name ~= "" and name or "platinum"
end
hl.bind("CTRL + Escape", function()
    if desktop_theme_name() ~= "win98" then return { ok = false } end
    hl.exec_cmd("qs -c mountainous ipc call chrome open start")
    return { ok = true }
end, { auto_consuming = true })

-- The same window menu as a Win98 caption's icon and taskbar right click.
-- Empty address and -1/-1 request the focused window's caption anchor.
hl.bind("ALT + Space", function()
    if desktop_theme_name() ~= "win98" then return { ok = false } end
    hl.exec_cmd("qs -c mountainous ipc call windows menu '' -1 -1")
    return { ok = true }
end, { auto_consuming = true })

hl.define_submap("topbar-access", "reset", function()
    hl.bind("B", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open bt"))
    hl.bind("W", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open wifi"))
    hl.bind("S", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open vol"))
    hl.bind("L", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open bri"))
    hl.bind("C", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open oci"))
    hl.bind("D", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open disk"))
    hl.bind("F", hl.dsp.exec_cmd("qs -c mountainous ipc call fleet toggle"))
    hl.bind("R", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open builder"))
    hl.bind("Y", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome open layout"))
    -- Both desktop themes draw N (Platinum's bar, Win98's tray); under any
    -- other theme N passes through.
    hl.bind("N", function()
        local theme = desktop_theme_name()
        if theme ~= "platinum" and theme ~= "win98" then return { ok = false } end
        hl.exec_cmd("qs -c mountainous ipc call chrome open ntf")
        return { ok = true }
    end, { auto_consuming = true })
    hl.bind("Escape", hl.dsp.exec_cmd("qs -c mountainous ipc call chrome hide"))
end)

-- O toggles the panels. Moved off SHIFT+P, which the omni bar's window
-- list now owns. A toggle lets the same key darken and wake the screen.
hl.bind(mod .. " + SHIFT + O", function()
    local any_on = false
    for _, m in ipairs(hl.get_monitors()) do
        if m.dpms_status then any_on = true end
    end
    hl.dispatch(hl.dsp.dpms({ action = any_on and "off" or "on" }))
end)
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

--------------------------------------------------------------------
-- Platinum window title bars. modules/hyprland.nix installs
-- titlebars.lua and the plugin it loads; a host without them skips this.
--------------------------------------------------------------------
if package.searchpath("titlebars", package.path) then
    local ok, err = pcall(function()
        require("titlebars").attach({ border_size = BORDER_SIZE, rounding = ROUNDING })
    end)
    if not ok then
        hl.notification.create({ text = "Title bars did not load: " .. tostring(err), timeout = 8000 })
    end
end

--------------------------------------------------------------------
-- Session restore, on hosts that install it. modules/session-restore.nix
-- puts session-restore.lua next to this file; other hosts skip this.
-- It shares the strip's capacity table and may hold compaction.
--------------------------------------------------------------------
--------------------------------------------------------------------
-- A Moonlight client as a second monitor, on hosts that run Sunshine.
-- modules/sunshine.nix installs second-screen.lua; other hosts skip this.
--------------------------------------------------------------------
if package.searchpath("second-screen", package.path) then
    local ok, err = pcall(function() require("second-screen").attach() end)
    if not ok then
        hl.notification.create({ text = "Second screen did not load: " .. tostring(err), timeout = 8000 })
    end
end

if package.searchpath("session-restore", package.path) then
    local ok, err = pcall(function()
        require("session-restore").attach({
            capacity = page_layout.capacity,
            default_capacity = page_layout.FALLBACK.cap,
            layout_defaults = { side = MASTER_SIDE, ratio = MASTER_RATIO },
            hold = page_layout.hold,
            compact = page_layout.compact,
        })
    end)
    if not ok then
        hl.notification.create({ text = "Session restore did not load: " .. tostring(err), timeout = 8000 })
    end
end
