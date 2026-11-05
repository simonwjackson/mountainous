-- Platinum and Memphis window title bars, drawn by hyprbars-platinum
-- plugin (modules/hyprland/hyprbars-platinum.patch, built in
-- modules/hyprland.nix). modules/hyprland.nix installs this file next to
-- hyprland.lua, which attaches it.
--
-- One plugin draws both desktop themes. Settings follow the three state
-- files on every parse and desktop-theme change, and so does each theme's
-- window motion (M.motion: Hyprland's animations). Unknown themes keep the
-- session's edge and corners. Both supported themes use square frames.
-- apply() only sets values. The buttons and rules are made once per config
-- load in attach(), because a config reload clears them and eval does not.
local M = {}

-- A stable path: a rebuild during a session changes the store path, and
-- Hyprland must not load a plugin built for the next Hyprland.
M.PLUGIN = "/etc/hypr/plugins/hyprbars-platinum.so"

-- The Platinum palettes, from modules/quickshell/PlatinumTokens.qml: a
-- window is a windoid's sibling, so it takes the menu surface, the bevel
-- pair, the raised box face and the menu text. Black is the OLED
-- appearance: a flat black bar, boxes as dim outlines, no stripes (the
-- stripe and bevel colours are the bar's own). checks.titlebars compares
-- these values with the tokens.
M.PALETTES = {
    light = {
        face = "dddddd", text = "000000", text_off = "8a8a8a",
        hi = "ffffff", lo = "999999", edge = "000000", box = "e6e6e6", rule = "000000",
    },
    ["drawing-board"] = {
        face = "e8e2d5", text = "24221e", text_off = "8a8477", hi = "e8e2d5", lo = "e8e2d5", edge = "3b3833", box = "fefcf8", rule = "3b3833",
    },
    dark = {
        face = "3a3a3a", text = "ececec", text_off = "767676",
        hi = "565656", lo = "1e1e1e", edge = "000000", box = "444444", rule = "000000",
    },
    black = {
        face = "000000", text = "e6e6e6", text_off = "5c5c5c",
        hi = "000000", lo = "000000", edge = "5c5c5c", box = "000000", rule = "000000",
    },
}

-- MemphisTokens.palette(). checks.titlebars compares every caption/frame
-- token in both appearances; Extra dark is intentionally ignored.
M.MEMPHIS_PALETTES = {
    light = {
        face = "c0c0c0", hi = "ffffff", li = "dfdfdf", lo = "808080", edge = "000000",
        text = "ffffff", text_off = "c0c0c0", glyph = "000000",
        caption1 = "000080", caption2 = "1084d0", inactive1 = "808080", inactive2 = "c0c0c0",
    },
    dark = {
        face = "3c3c3c", hi = "7a7a7a", li = "565656", lo = "222222", edge = "000000",
        text = "ffffff", text_off = "9a9a9a", glyph = "ececec",
        -- Steel, not navy, in dark grey (MemphisTokens.palette()).
        caption1 = "26364f", caption2 = "56708e", inactive1 = "2a2a2a", inactive2 = "4a4a4a",
    },
}

-- BEGIN GENERATED SYSTEM PALETTES
M.SCHEME_PALETTES = {
    ["brick"] = { face = "c2bfa5", hi = "e1e0d2", li = "c2bfa5", lo = "8d8961", edge = "000000", text = "e1e0d2", text_off = "e1e0d2", glyph = "000000", caption1 = "800000", caption2 = "b07440", inactive1 = "8d8961", inactive2 = "c8b870" },
    ["desert"] = { face = "d5ccbb", hi = "eae6dd", li = "d5ccbb", lo = "a28d68", edge = "000000", text = "ffffff", text_off = "ffffff", glyph = "000000", caption1 = "008080", caption2 = "84bdaa", inactive1 = "a28d68", inactive2 = "e8d080" },
    ["eggplant"] = { face = "90b0a8", hi = "c8d8d8", li = "90b0a8", lo = "588078", edge = "000000", text = "ffffff", text_off = "588078", glyph = "000000", caption1 = "588078", caption2 = "834b83", inactive1 = "90b0a8", inactive2 = "cbbdd2" },
    ["lilac"] = { face = "aea8d9", hi = "d8d5ec", li = "aea8d9", lo = "5a4eb1", edge = "000000", text = "ffffff", text_off = "ffffff", glyph = "000000", caption1 = "5a4eb1", caption2 = "b68fcb", inactive1 = "808080", inactive2 = "b8b4d0" },
    ["maple"] = { face = "e6d8ae", hi = "f2ecd7", li = "e6d8ae", lo = "c6a646", edge = "000000", text = "ffffff", text_off = "f2ecd7", glyph = "000000", caption1 = "800000", caption2 = "c09c38", inactive1 = "c6a646", inactive2 = "e0c888" },
    ["marine"] = { face = "88c0b8", hi = "c8e0d8", li = "88c0b8", lo = "489088", edge = "000000", text = "ffffff", text_off = "c0c0c0", glyph = "000000", caption1 = "000080", caption2 = "18b4c0", inactive1 = "489088", inactive2 = "78ccd8" },
    ["plum"] = { face = "a89890", hi = "d8d0c8", li = "a89890", lo = "786058", edge = "000000", text = "ffffff", text_off = "a89890", glyph = "000000", caption1 = "484060", caption2 = "a084b8", inactive1 = "786058", inactive2 = "a89878" },
    ["pumpkin"] = { face = "ecd59d", hi = "f5eacf", li = "ecd59d", lo = "d7a52f", edge = "000000", text = "ffffff", text_off = "f5eacf", glyph = "000000", caption1 = "d7a52f", caption2 = "e0cc88", inactive1 = "a0a0a4", inactive2 = "d0cc90" },
    ["rainy-day"] = { face = "8399b1", hi = "c1ccd9", li = "8399b1", lo = "4f657d", edge = "000000", text = "ffffff", text_off = "c1ccd9", glyph = "000000", caption1 = "4f657d", caption2 = "80b4d0", inactive1 = "808080", inactive2 = "b0bcd0" },
    ["red-white-blue"] = { face = "c0c0c0", hi = "ffffff", li = "c0c0c0", lo = "808080", edge = "000000", text = "ffffff", text_off = "c0c0c0", glyph = "000000", caption1 = "800000", caption2 = "0010a8", inactive1 = "808080", inactive2 = "babec9" },
    ["rose"] = { face = "cfafb7", hi = "e7d8dc", li = "cfafb7", lo = "9f6070", edge = "000000", text = "ffffff", text_off = "7d7d7d", glyph = "000000", caption1 = "9f6070", caption2 = "d8ccd0", inactive1 = "a0a0a4", inactive2 = "d0d4d0" },
    ["slate"] = { face = "9db9c8", hi = "cedce3", li = "9db9c8", lo = "558097", edge = "000000", text = "ffffff", text_off = "c0c0c0", glyph = "000000", caption1 = "558097", caption2 = "88b8d8", inactive1 = "808080", inactive2 = "a0bcc8" },
    ["spruce"] = { face = "a2c8a9", hi = "d0e3d3", li = "a2c8a9", lo = "599764", edge = "000000", text = "ffffff", text_off = "d0e3d3", glyph = "000000", caption1 = "599764", caption2 = "98c8e8", inactive1 = "808080", inactive2 = "a8ccb0" },
    ["storm"] = { face = "c0c0c0", hi = "ffffff", li = "c0c0c0", lo = "808080", edge = "000000", text = "ffffff", text_off = "c0c0c0", glyph = "000000", caption1 = "800080", caption2 = "388cb0", inactive1 = "808080", inactive2 = "a8aca8" },
    ["teal"] = { face = "c0c0c0", hi = "ffffff", li = "c0c0c0", lo = "808080", edge = "000000", text = "ffffff", text_off = "fffbf0", glyph = "000000", caption1 = "008080", caption2 = "00ccd8", inactive1 = "808080", inactive2 = "98c8b8" },
    ["wheat"] = { face = "dedea0", hi = "eeeed0", li = "dedea0", lo = "bcbc41", edge = "000000", text = "ffffff", text_off = "ffffff", glyph = "000000", caption1 = "808000", caption2 = "c8b048", inactive1 = "bcbc41", inactive2 = "b8b880" },
    ["high-contrast-1"] = { face = "000000", hi = "c0c0c0", li = "ffffff", lo = "808080", edge = "ffffff", text = "ffffff", text_off = "000000", glyph = "ffffff", caption1 = "0000ff", caption2 = "0000ff", inactive1 = "00ffff", inactive2 = "00ffff" },
    ["high-contrast-2"] = { face = "000000", hi = "c0c0c0", li = "ffffff", lo = "808080", edge = "ffffff", text = "000000", text_off = "ffffff", glyph = "00ff00", caption1 = "00ffff", caption2 = "00ffff", inactive1 = "0000ff", inactive2 = "0000ff" },
    ["high-contrast-black"] = { face = "000000", hi = "c0c0c0", li = "ffffff", lo = "808080", edge = "ffffff", text = "ffffff", text_off = "ffffff", glyph = "ffffff", caption1 = "800080", caption2 = "800080", inactive1 = "008000", inactive2 = "008000" },
    ["high-contrast-white"] = { face = "ffffff", hi = "c0c0c0", li = "c0c0c0", lo = "808080", edge = "000000", text = "ffffff", text_off = "000000", glyph = "000000", caption1 = "000000", caption2 = "000000", inactive1 = "ffffff", inactive2 = "ffffff" },
}
-- END GENERATED SYSTEM PALETTES

-- Both desktop themes are square. The plugin's frame draws their black edge,
-- because a hair is whole device pixels (2 at scale 1.5) and Hyprland's
-- border is whole logical pixels (1.5 device pixels, rounded unevenly).
-- attach() takes the session's own values for every other theme.
M.PLATINUM_WINDOW = { border_size = 0, rounding = 0 }
M.session = { border_size = 0, rounding = 6 }
-- Hyprland 0.56.2's own groupbar values (config/values/ConfigValues.cpp),
-- put back when the theme has no bars.
M.GROUPBAR_DEFAULT = { rounding = 1, col = { active = "rgba(ffff0066)", inactive = "rgba(77770066)" } }

-- Window and layer motion. Neither Mac OS 8 nor Memphis faded or
-- popped a window: a window appeared and went at once, and the shell
-- draws the OS's own motion over it (Memphis's caption animation, the
-- Finder's zoom rectangles; modules/quickshell/WindowMotion.qml and each
-- theme's motion layer). Under both themes Hyprland's window, fade and
-- layer animations are off, so windows, Quickshell's menus, tray windows,
-- dialogs and tooltips (all layer surfaces) and popups cut. Page switches
-- (workspaces) keep the session's slide: neither OS had pages.
M.MOTION_LEAVES = { "windows", "fade", "layers" }
-- hyprland.lua's own values for the first two (its hl.animation lines;
-- checks.titlebars compares them), and Hyprland's global for layers,
-- which hyprland.lua leaves to inherit. Put back for any other theme.
M.SESSION_MOTION = {
    windows = { enabled = true, speed = 4, bezier = "quick" },
    fade = { enabled = true, speed = 4, bezier = "quick" },
    layers = { enabled = true, speed = 8, bezier = "default" },
}

local function read(name)
    local dir = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
    local file = io.open(dir .. "/mountainous/" .. name, "r")
    if not file then return "" end
    local value = (file:read("*l") or ""):match("^%s*(.-)%s*$")
    file:close()
    return value
end

-- desktop-theme's own defaults: a missing or unknown name is Platinum, a
-- missing mode is dark, a missing extra file is off.
function M.state()
    local name = read("theme-name")
    if name == "" then name = "platinum" end
    local mode = read("theme") == "light" and "light" or "dark"
    local appearance = read("theme-appearance")
    local known = name == "memphis" and (M.SCHEME_PALETTES[appearance] or appearance == "standard" or appearance == "dark-grey")
        or name == "platinum" and (appearance == "light" or appearance == "dark-grey" or appearance == "drawing-board")
    if not known then appearance = mode == "dark" and "dark-grey" or (name == "memphis" and "standard" or "light") end
    mode = (appearance == "dark-grey" or appearance == "high-contrast-black" or appearance == "high-contrast-1" or appearance == "high-contrast-2") and "dark" or "light"
    return { name = name, mode = mode, appearance = appearance, extra = read("theme-extra") == "on" }
end

-- The palette name for a state, or nil for an unsupported theme.
function M.appearance(state)
    if state.name == "memphis" then
        if M.SCHEME_PALETTES[state.appearance] then return "memphis_" .. state.appearance end
        return "memphis_" .. (state.mode == "light" and "light" or "dark")
    end
    if state.name ~= "platinum" then return nil end
    if state.appearance == "drawing-board" then return "drawing-board" end
    if state.mode == "light" then return "light" end
    return state.extra and "black" or "dark"
end

local function rgb(hex) return "rgb(" .. hex .. ")" end

-- The values for one state, as a pure table. Explicit false selects the
-- generation-52 capability set; omitted defaults to the current plugin.
function M.settings(state, memphis_supported)
    local key = M.appearance(state)
    if state.name == "memphis" and memphis_supported == false then key = nil end
    if not key then
        return {
            general = { border_size = M.session.border_size },
            decoration = { rounding = M.session.rounding },
            group = { groupbar = M.GROUPBAR_DEFAULT },
            plugin = { hyprbars = { enabled = false } },
        }
    end
    local memphis = state.name == "memphis"
    local p = memphis and (M.SCHEME_PALETTES[state.appearance] or M.MEMPHIS_PALETTES[state.mode == "light" and "light" or "dark"]) or M.PALETTES[key]
    local style = {
        platinum = true, -- shared client-decoration test and frame owner
        -- Memphis computes its 18-u caption plus 1-u seam per output; the
        -- config height is the caption at the default 1.5 scale.
        bar_height = memphis and 24 or 20,
        bar_text_font = memphis and "W95FA Grid" or "ChicagoFLF",
        bar_text_size = memphis and 17 or 12,
        bar_text_align = memphis and "left" or "center",
        enabled = true,
        bar_color = rgb(p.face),
        ["col.text"] = rgb(p.text),
        platinum_title_inactive = rgb(p.text_off),
        platinum_hi = rgb(p.hi), platinum_lo = rgb(p.lo),
        platinum_frame = rgb(p.edge), platinum_box = rgb(memphis and p.face or p.box),
        platinum_rule = rgb(memphis and p.edge or p.rule),
    }
    if memphis_supported ~= false then style.memphis = memphis end
    if memphis then
        style.memphis_li = rgb(p.li)
        style.memphis_caption1 = rgb(p.caption1)
        style.memphis_caption2 = rgb(p.caption2)
        style.memphis_inactive1 = rgb(p.inactive1)
        style.memphis_inactive2 = rgb(p.inactive2)
        style.memphis_button_text = rgb(p.glyph)
    end
    return {
        general = { border_size = M.PLATINUM_WINDOW.border_size },
        decoration = { rounding = M.PLATINUM_WINDOW.rounding },
        -- A group keeps Hyprland's tab bar and no title bar. Its indicator
        -- takes the title colours, square.
        group = { groupbar = { rounding = 0, col = { active = rgb(p.text), inactive = rgb(p.text_off) } } },
        plugin = { hyprbars = style },
    }
end

-- The hl.animation calls for a state, as a pure list.
function M.motion(state)
    local themed = state.name == "platinum" or state.name == "memphis"
    local out = {}
    for _, leaf in ipairs(M.MOTION_LEAVES) do
        local a = { leaf = leaf, enabled = false }
        if not themed then
            local v = M.SESSION_MOTION[leaf]
            a = { leaf = leaf, enabled = v.enabled, speed = v.speed, bezier = v.bezier }
        end
        table.insert(out, a)
    end
    return out
end

-- Set the motion for the theme on disk. A leaf Hyprland rejects keeps
-- its value; the others still apply.
function M.apply_motion()
    if type(hl.animation) ~= "function" then return false end
    local ok_all = true
    for _, a in ipairs(M.motion(M.state())) do
        if not pcall(hl.animation, a) then ok_all = false end
    end
    return ok_all
end

-- The stable plugin path can still name an older loaded library after a
-- rebuild. hl.get_config is a read-only lookup: an unknown key returns nil
-- plus a message, without adding a config error (unlike hl.config). Check
-- every new option, including false-valued booleans. Do not cache absence:
-- the first config parse can run before plugin registration.
local function supports_memphis()
    if type(hl.get_config) ~= "function" then return false end
    for _, name in ipairs({ "memphis", "memphis_li", "memphis_caption1", "memphis_caption2",
        "memphis_inactive1", "memphis_inactive2", "memphis_button_text" }) do
        local ok, value = pcall(hl.get_config, "plugin:hyprbars:" .. name)
        if not ok or value == nil then return false end
    end
    return true
end

-- Set the motion, the bars and the window frame for the theme on disk.
-- Without the plugin (it failed to load) the windows keep the session's
-- look; the motion follows the theme either way.
function M.apply()
    -- Motion first: it needs no plugin.
    M.apply_motion()
    if not hl.plugin.hyprbars then
        hl.config({ general = { border_size = M.session.border_size }, decoration = { rounding = M.session.rounding } })
        return false
    end
    hl.config(M.settings(M.state(), supports_memphis()))
    hl.plugin.hyprbars.refresh()
    return true
end

local function dispatch(lua)
    return "hyprctl --instance 0 dispatch '" .. lua .. "'"
end

-- opts: the session's border_size and rounding, for themes without bars.
function M.attach(opts)
    opts = opts or {}
    M.session = {
        border_size = opts.border_size or M.session.border_size,
        rounding = opts.rounding or M.session.rounding,
    }

    -- Every parse must name the plugin: after a parse Hyprland loads the
    -- plugins it named and unloads the rest (ConfigManager.cpp
    -- handlePluginLoads), and a change reloads the config. So the first
    -- parse loads it, and the second parse finds hl.plugin.hyprbars.
    hl.plugin.load(M.PLUGIN)

    local zoom = dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })')
    hl.config({ plugin = { hyprbars = {
        bar_padding = 7,
        bar_button_padding = 5,
        bar_precedence_over_border = true,
        bar_part_of_window = true,
        -- Mac OS 8 shades a window on a double click; here that would be
        -- collapse, which hides it. Zoom is the safer double click.
        on_double_click = zoom,
    } } })

    -- A group shows Hyprland's own tab bar instead. Clients that draw their
    -- own title bar (GTK4/libadwaita, GTK3, a normal Chromium window) are
    -- found by the plugin and get none.
    hl.window_rule({ name = "titlebars-group", match = { group = true }, ["hyprbars:no_bar"] = true })

    if hl.plugin.hyprbars then
        -- Close on the left. On the right, collapse outermost, then zoom.
        hl.plugin.hyprbars.add_button({ side = "left", icon = "close", size = 13,
            bg_color = "rgb(dddddd)", fg_color = "rgb(000000)", action = dispatch("hl.dsp.window.close()") })
        hl.plugin.hyprbars.add_button({ side = "right", icon = "collapse", size = 13,
            bg_color = "rgb(dddddd)", fg_color = "rgb(000000)", action = "qs -c mountainous ipc call windows collapseActive" })
        hl.plugin.hyprbars.add_button({ side = "right", icon = "zoom", size = 13,
            bg_color = "rgb(dddddd)", fg_color = "rgb(000000)", action = zoom })
    end

    M.apply()
end

return M
