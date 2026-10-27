-- Mac OS 8 Platinum window title bars, drawn by the hyprbars-platinum
-- plugin (modules/hyprland/hyprbars-platinum.patch, built in
-- modules/hyprland.nix). modules/hyprland.nix installs this file next to
-- hyprland.lua, which attaches it.
--
-- The bars follow the desktop theme. Under Platinum they take its
-- appearance: light, dark grey, or black (extra dark). Under any other
-- theme there are no bars, and windows keep the session's own border and
-- corners. The theme lives in three files under
-- $XDG_STATE_HOME/mountainous (modules/theme.nix: theme-name, theme,
-- theme-extra). This module reads them at every config load, and
-- desktop-theme calls apply() after each change:
--
--   hyprctl eval 'local ok, t = pcall(require, "titlebars"); if ok then t.apply() end'
--
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

-- Platinum windows are square. The plugin's frame draws their black edge,
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

-- The palette name for a state, or nil when the theme draws no bars.
function M.appearance(state)
    if state.name ~= "platinum" then return nil end
    if state.mode == "light" then return "light" end
    return state.extra and "black" or "dark"
end

local function rgb(hex) return "rgb(" .. hex .. ")" end

-- The values for one state, as a pure table, so it can be checked headless.
function M.settings(state)
    local key = M.appearance(state)
    if not key then
        return {
            general = { border_size = M.session.border_size },
            decoration = { rounding = M.session.rounding },
            group = { groupbar = M.GROUPBAR_DEFAULT },
            plugin = { hyprbars = { enabled = false } },
        }
    end
    local p = M.PALETTES[key]
    return {
        general = { border_size = M.PLATINUM_WINDOW.border_size },
        decoration = { rounding = M.PLATINUM_WINDOW.rounding },
        -- A group keeps Hyprland's tab bar and no title bar. Its indicator
        -- takes the title colours, square.
        group = { groupbar = { rounding = 0, col = { active = rgb(p.text), inactive = rgb(p.text_off) } } },
        plugin = { hyprbars = {
            enabled = true,
            bar_color = rgb(p.face),
            ["col.text"] = rgb(p.text),
            platinum_title_inactive = rgb(p.text_off),
            platinum_hi = rgb(p.hi),
            platinum_lo = rgb(p.lo),
            platinum_frame = rgb(p.edge),
            platinum_box = rgb(p.box),
            platinum_rule = rgb(p.rule),
        } },
    }
end

-- Set the bars and the window frame for the theme on disk. Without the
-- plugin (it failed to load) the windows keep the session's look.
function M.apply()
    if not hl.plugin.hyprbars then
        hl.config({ general = { border_size = M.session.border_size }, decoration = { rounding = M.session.rounding } })
        return false
    end
    hl.config(M.settings(M.state()))
    hl.plugin.hyprbars.refresh()
    return true
end

local function dispatch(lua)
    return "hyprctl dispatch '" .. lua .. "'"
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
        platinum = true,
        bar_height = 20,
        bar_text_font = "ChicagoFLF",
        bar_text_size = 12,
        bar_text_align = "center",
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
