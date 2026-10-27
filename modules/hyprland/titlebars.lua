-- Platinum and Windows 98 window title bars, drawn by hyprbars-platinum
-- plugin (modules/hyprland/hyprbars-platinum.patch, built in
-- modules/hyprland.nix). modules/hyprland.nix installs this file next to
-- hyprland.lua, which attaches it.
--
-- One plugin draws both desktop themes. Settings follow the three state
-- files on every parse and desktop-theme change. Unknown themes keep the
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
    dark = {
        face = "3a3a3a", text = "ececec", text_off = "767676",
        hi = "565656", lo = "1e1e1e", edge = "000000", box = "444444", rule = "000000",
    },
    black = {
        face = "000000", text = "e6e6e6", text_off = "5c5c5c",
        hi = "000000", lo = "000000", edge = "5c5c5c", box = "000000", rule = "000000",
    },
}

-- Win98Tokens.palette(). checks.titlebars compares every caption/frame
-- token in both appearances; Extra dark is intentionally ignored.
M.WIN98_PALETTES = {
    light = {
        face = "c0c0c0", hi = "ffffff", li = "dfdfdf", lo = "808080", edge = "000000",
        text = "ffffff", text_off = "c0c0c0", glyph = "000000",
        caption1 = "000080", caption2 = "1084d0", inactive1 = "808080", inactive2 = "c0c0c0",
    },
    dark = {
        face = "3c3c3c", hi = "7a7a7a", li = "565656", lo = "222222", edge = "000000",
        text = "ffffff", text_off = "9a9a9a", glyph = "ececec",
        -- Steel, not navy, in dark grey (Win98Tokens.palette()).
        caption1 = "26364f", caption2 = "56708e", inactive1 = "2a2a2a", inactive2 = "4a4a4a",
    },
}

-- Both desktop themes are square. The plugin's frame draws their black edge,
-- because a hair is whole device pixels (2 at scale 1.5) and Hyprland's
-- border is whole logical pixels (1.5 device pixels, rounded unevenly).
-- attach() takes the session's own values for every other theme.
M.PLATINUM_WINDOW = { border_size = 0, rounding = 0 }
M.session = { border_size = 0, rounding = 6 }
-- Hyprland 0.56.2's own groupbar values (config/values/ConfigValues.cpp),
-- put back when the theme has no bars.
M.GROUPBAR_DEFAULT = { rounding = 1, col = { active = "rgba(ffff0066)", inactive = "rgba(77770066)" } }

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
    return { name = name, mode = mode, extra = read("theme-extra") == "on" }
end

-- The palette name for a state, or nil for an unsupported theme.
function M.appearance(state)
    if state.name == "win98" then return "win98_" .. (state.mode == "light" and "light" or "dark") end
    if state.name ~= "platinum" then return nil end
    if state.mode == "light" then return "light" end
    return state.extra and "black" or "dark"
end

local function rgb(hex) return "rgb(" .. hex .. ")" end

-- The values for one state, as a pure table. Explicit false selects the
-- generation-52 capability set; omitted defaults to the current plugin.
function M.settings(state, win98_supported)
    local key = M.appearance(state)
    if state.name == "win98" and win98_supported == false then key = nil end
    if not key then
        return {
            general = { border_size = M.session.border_size },
            decoration = { rounding = M.session.rounding },
            group = { groupbar = M.GROUPBAR_DEFAULT },
            plugin = { hyprbars = { enabled = false } },
        }
    end
    local win98 = state.name == "win98"
    local p = win98 and M.WIN98_PALETTES[state.mode == "light" and "light" or "dark"] or M.PALETTES[key]
    local style = {
        platinum = true, -- shared client-decoration test and frame owner
        -- Win98 computes its 18-u caption plus 1-u seam per output; the
        -- config height is the caption at the default 1.5 scale.
        bar_height = win98 and 24 or 20,
        bar_text_font = win98 and "W95FA Grid" or "ChicagoFLF",
        bar_text_size = win98 and 17 or 12,
        bar_text_align = win98 and "left" or "center",
        enabled = true,
        bar_color = rgb(p.face),
        ["col.text"] = rgb(p.text),
        platinum_title_inactive = rgb(p.text_off),
        platinum_hi = rgb(p.hi), platinum_lo = rgb(p.lo),
        platinum_frame = rgb(p.edge), platinum_box = rgb(win98 and p.face or p.box),
        platinum_rule = rgb(win98 and p.edge or p.rule),
    }
    if win98_supported ~= false then style.win98 = win98 end
    if win98 then
        style.win98_li = rgb(p.li)
        style.win98_caption1 = rgb(p.caption1)
        style.win98_caption2 = rgb(p.caption2)
        style.win98_inactive1 = rgb(p.inactive1)
        style.win98_inactive2 = rgb(p.inactive2)
        style.win98_button_text = rgb(p.glyph)
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

-- The stable plugin path can still name an older loaded library after a
-- rebuild. hl.get_config is a read-only lookup: an unknown key returns nil
-- plus a message, without adding a config error (unlike hl.config). Check
-- every new option, including false-valued booleans. Do not cache absence:
-- the first config parse can run before plugin registration.
local function supports_win98()
    if type(hl.get_config) ~= "function" then return false end
    for _, name in ipairs({ "win98", "win98_li", "win98_caption1", "win98_caption2",
        "win98_inactive1", "win98_inactive2", "win98_button_text" }) do
        local ok, value = pcall(hl.get_config, "plugin:hyprbars:" .. name)
        if not ok or value == nil then return false end
    end
    return true
end

-- Set the bars and the window frame for the theme on disk. Without the
-- plugin (it failed to load) the windows keep the session's look.
function M.apply()
    if not hl.plugin.hyprbars then
        hl.config({ general = { border_size = M.session.border_size }, decoration = { rounding = M.session.rounding } })
        return false
    end
    hl.config(M.settings(M.state(), supports_win98()))
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
