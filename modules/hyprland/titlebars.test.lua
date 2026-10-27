-- titlebars.lua without a compositor: the theme files decide the
-- appearance, each appearance sets the plugin and the window edge, attach()
-- loads the plugin on every parse and makes the boxes once, and the
-- palettes are PlatinumTokens.qml's.
-- Run: lua titlebars.test.lua titlebars.lua PlatinumTokens.qml hyprland.lua
local module_path, tokens_path, hyprland_path = arg[1], arg[2], arg[3]

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end

local failures = 0
local function check(ok, what)
    if not ok then
        failures = failures + 1
        io.stderr:write("FAIL: " .. what .. "\n")
    end
end

-- A state directory the module reads through XDG_STATE_HOME.
local dir = os.tmpname()
os.remove(dir)
assert(os.execute("mkdir -p " .. dir .. "/mountainous"))
local real_getenv = os.getenv
os.getenv = function(name)
    if name == "XDG_STATE_HOME" then return dir end
    return real_getenv(name)
end
local function write_state(name, mode, extra)
    for file, value in pairs({ ["theme-name"] = name, theme = mode, ["theme-extra"] = extra }) do
        local path = dir .. "/mountainous/" .. file
        if value == nil then
            os.remove(path)
        else
            local f = assert(io.open(path, "w"))
            f:write(value .. "\n")
            f:close()
        end
    end
end

-- A recording stand-in for Hyprland's hl table.
local calls
local function fresh_hl(loaded)
    calls = { config = {}, load = {}, rules = {}, buttons = {}, refresh = 0 }
    _G.hl = {
        config = function(t) table.insert(calls.config, t) end,
        window_rule = function(t) table.insert(calls.rules, t) end,
        plugin = {
            load = function(path) table.insert(calls.load, path) end,
        },
    }
    if loaded then
        hl.plugin.hyprbars = {
            add_button = function(t) table.insert(calls.buttons, t) end,
            refresh = function() calls.refresh = calls.refresh + 1 end,
        }
    end
end

fresh_hl(false)
local M = dofile(module_path)

-- The theme on disk, with desktop-theme's defaults.
write_state(nil, nil, nil)
local s = M.state()
check(s.name == "platinum" and s.mode == "dark" and s.extra == false, "missing files are platinum, dark, extra off")
check(M.appearance(s) == "dark", "the default appearance is dark grey")
write_state("platinum", "light", "on")
check(M.appearance(M.state()) == "light", "light ignores extra dark")
write_state("platinum", "dark", "on")
check(M.appearance(M.state()) == "black", "dark with extra is black")
write_state("  platinum  ", "dark", "off")
check(M.appearance(M.state()) == "dark", "whitespace is trimmed")
write_state("win98", "light", "off")
check(M.appearance(M.state()) == nil, "win98 draws no bars")

-- Each appearance: the plugin on with its palette, square windows with
-- no Hyprland border; without bars, the session's edge and corners.
M.session = { border_size = 0, rounding = 6 }
for _, key in ipairs({ "light", "dark", "black" }) do
    local state = ({ light = { name = "platinum", mode = "light", extra = false },
        dark = { name = "platinum", mode = "dark", extra = false },
        black = { name = "platinum", mode = "dark", extra = true } })[key]
    local t = M.settings(state)
    local p = M.PALETTES[key]
    local hb = t.plugin.hyprbars
    check(hb.enabled == true, key .. ": bars enabled")
    check(hb.bar_color == "rgb(" .. p.face .. ")", key .. ": bar face")
    check(hb["col.text"] == "rgb(" .. p.text .. ")", key .. ": title")
    check(hb.platinum_title_inactive == "rgb(" .. p.text_off .. ")", key .. ": inactive title")
    for field, value in pairs({ platinum_hi = p.hi, platinum_lo = p.lo, platinum_frame = p.edge,
        platinum_box = p.box, platinum_rule = p.rule }) do
        check(hb[field] == "rgb(" .. value .. ")", key .. ": " .. field)
    end
    check(t.general.border_size == 0 and t.decoration.rounding == 0, key .. ": square, no Hyprland border")
    check(t.group.groupbar.rounding == 0, key .. ": square group indicator")
end
local none = M.settings({ name = "win98", mode = "light", extra = false })
check(none.plugin.hyprbars.enabled == false, "win98: bars off")
check(none.general.border_size == 0 and none.decoration.rounding == 6, "win98: the session's edge and corners")
check(none.group.groupbar.col.active == "rgba(ffff0066)", "win98: Hyprland's own group indicator")

-- attach() before the plugin has loaded: it asks for the plugin, makes no
-- boxes, and keeps the session's look.
write_state("platinum", "light", "off")
fresh_hl(false)
M.attach({ border_size = 3, rounding = 9 })
check(#calls.load == 1 and calls.load[1] == M.PLUGIN, "first parse loads the plugin from " .. M.PLUGIN)
check(#calls.buttons == 0, "no boxes before the plugin loads")
local last = calls.config[#calls.config]
check(last.general.border_size == 3 and last.decoration.rounding == 9 and last.plugin == nil,
    "without the plugin the session's edge stays")

-- attach() on the parse after the load: the plugin again (Hyprland unloads
-- a plugin a parse leaves out), the boxes in Mac OS 8 order, the group rule,
-- and the Platinum values.
fresh_hl(true)
M.attach({ border_size = 0, rounding = 6 })
check(#calls.load == 1 and calls.load[1] == M.PLUGIN, "every parse names the plugin")
local order = {}
for _, b in ipairs(calls.buttons) do table.insert(order, b.side .. ":" .. b.icon) end
check(table.concat(order, " ") == "left:close right:collapse right:zoom",
    "boxes: close left, collapse outermost right, then zoom; got " .. table.concat(order, " "))
check(calls.buttons[2].action == "qs -c mountainous ipc call windows collapseActive", "collapse hides the window")
check(calls.buttons[1].action:find("hl.dsp.window.close()", 1, true) ~= nil, "close closes")
check(calls.buttons[3].action:find('mode = "maximized", action = "toggle"', 1, true) ~= nil, "zoom toggles maximized")
check(#calls.rules == 1 and calls.rules[1].match.group == true and calls.rules[1]["hyprbars:no_bar"] == true,
    "a group gets no bar")
last = calls.config[#calls.config]
check(last.plugin.hyprbars.enabled == true and last.plugin.hyprbars.bar_color == "rgb(dddddd)", "light Platinum applied")
check(calls.refresh == 1, "apply() redraws the bars")
local static = calls.config[1].plugin.hyprbars
check(static.platinum == true and static.bar_text_font == "ChicagoFLF" and static.bar_height == 20, "Platinum bar shape")
check(static.on_double_click == calls.buttons[3].action, "a double click zooms")

-- apply() after desktop-theme changes the files: values only.
write_state("win98", "light", "off")
fresh_hl(true)
check(M.apply() == true, "apply with the plugin")
check(#calls.buttons == 0 and #calls.rules == 0 and #calls.load == 0, "apply only sets values")
check(calls.config[1].plugin.hyprbars.enabled == false and calls.config[1].decoration.rounding == 6, "apply follows win98")

-- The palettes are the tokens'. A windoid's colours for light and dark
-- grey; the black bar's for black.
local qml = read_file(tokens_path)
local function two(name)
    return qml:match("property color " .. name .. ': dark %? "#(%x+)" : "#(%x+)"')
end
local function three(name)
    return qml:match("property color " .. name .. ': !dark %? "#(%x+)" : barBlack %? "#(%x+)" : "#(%x+)"')
end
local function same(a, b, what) check(a ~= nil and a == b, what .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
for field, token in pairs({ face = "menuSurface", text = "menuText", text_off = "menuTextOff",
    hi = "bevelLight", lo = "bevelDark", box = "raised" }) do
    local dark, light = two(token)
    same(M.PALETTES.light[field], light, "light " .. field .. " = " .. token)
    same(M.PALETTES.dark[field], dark, "dark " .. field .. " = " .. token)
end
local edge = qml:match('property color menuEdge: "#(%x+)"')
same(M.PALETTES.light.edge, edge, "light edge = menuEdge")
same(M.PALETTES.dark.edge, edge, "dark edge = menuEdge")
local _, black_face = three("barSurface")
local _, black_text = three("barText")
local _, black_off = three("barTextOff")
local _, black_edge = three("ridgeLow")
same(M.PALETTES.black.face, black_face, "black face = barSurface")
same(M.PALETTES.black.text, black_text, "black title = barText")
same(M.PALETTES.black.text_off, black_off, "black inactive title = barTextOff")
same(M.PALETTES.black.edge, black_edge, "black box edge = ridgeLow")
check(M.PALETTES.black.hi == M.PALETTES.black.face and M.PALETTES.black.lo == M.PALETTES.black.face,
    "black is flat: no stripes, no bevel")

-- hyprland.lua hands the module the values it uses itself.
local hypr = read_file(hyprland_path)
check(hypr:find('require("titlebars").attach({ border_size = BORDER_SIZE, rounding = ROUNDING })', 1, true) ~= nil,
    "hyprland.lua attaches titlebars with its own edge")
check(hypr:find("border_size = BORDER_SIZE,", 1, true) ~= nil and hypr:find("rounding = ROUNDING,", 1, true) ~= nil,
    "hyprland.lua's config uses the same edge")

os.execute("rm -rf " .. dir)
if failures > 0 then
    io.stderr:write(failures .. " titlebars check(s) failed\n")
    os.exit(1)
end
print("titlebars: appearances, settings, attach, apply, tokens pass")
