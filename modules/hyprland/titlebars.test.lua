-- titlebars.lua without a compositor: the theme files decide the
-- appearance, each appearance sets the plugin and the window edge, attach()
-- loads the plugin on every parse and makes the boxes once, and the
-- palettes are PlatinumTokens.qml's.
-- Run: lua titlebars.test.lua titlebars.lua kit-palettes.json hyprland.lua
local module_path, palettes_path, hyprland_path = arg[1], arg[2], arg[3]

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
local OLD_OPTIONS = {}
for _, name in ipairs({ "enabled", "platinum", "bar_height", "bar_text_font", "bar_text_size", "bar_text_align",
    "bar_padding", "bar_button_padding", "bar_precedence_over_border", "bar_part_of_window", "on_double_click",
    "bar_color", "col.text", "platinum_title_inactive", "platinum_hi", "platinum_lo", "platinum_frame",
    "platinum_box", "platinum_rule" }) do OLD_OPTIONS[name] = true end
local MEMPHIS_OPTIONS = { "memphis", "memphis_li", "memphis_caption1", "memphis_caption2", "memphis_inactive1", "memphis_inactive2", "memphis_button_text" }
local function fresh_hl(loaded, opts)
    opts = opts or {}
    calls = { config = {}, load = {}, rules = {}, buttons = {}, refresh = 0, queries = {}, rejected = {}, animation = {} }
    _G.hl = {
        animation = not opts.no_animation and function(t)
            if opts.reject_leaf == t.leaf then error("no such animation leaf") end
            table.insert(calls.animation, t)
        end or nil,
        config = function(t)
            if opts.old and t.plugin and t.plugin.hyprbars then
                for name in pairs(t.plugin.hyprbars) do
                    if not OLD_OPTIONS[name] then
                        table.insert(calls.rejected, name)
                        error("old plugin rejects option " .. name)
                    end
                end
            end
            table.insert(calls.config, t)
        end,
        get_config = function(key)
            table.insert(calls.queries, key)
            local name = key:match("^plugin:hyprbars:(.+)$")
            if opts.probe_throws then error("configuration query unavailable") end
            if opts.old or name == opts.missing then return nil, "unknown config key" end
            -- A supported boolean option can be false. Presence is not truthiness.
            if name == "memphis" then return false end
            return 0
        end,
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
write_state("memphis", "light", "off")
check(M.appearance(M.state()) == "memphis_light", "memphis selects its light appearance")

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
for _, mode in ipairs({ "light", "dark" }) do
    local state = { name = "memphis", mode = mode, extra = true }
    local t = M.settings(state)
    check(t.plugin.hyprbars.enabled and t.plugin.hyprbars.memphis, mode .. ": Memphis bars enabled")
    check(t.decoration.rounding == 0 and t.general.border_size == 0, mode .. ": Memphis square edge")
    check(t.plugin.hyprbars.bar_text_font == "W95FA Grid", mode .. ": Memphis font")
end
local none = M.settings({ name = "unknown", mode = "light", extra = false })
check(none.plugin.hyprbars.enabled == false, "unknown theme: bars off")
check(none.decoration.rounding == 6, "unknown theme: session corners")

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
check(last.plugin.hyprbars.platinum == true and last.plugin.hyprbars.bar_text_font == "ChicagoFLF" and last.plugin.hyprbars.bar_height == 20, "Platinum bar shape")
check(static.on_double_click == calls.buttons[3].action, "a double click zooms")

-- apply() after desktop-theme changes the files: values only.
write_state("memphis", "light", "off")
fresh_hl(true)
check(M.apply() == true, "apply with the plugin")
check(#calls.buttons == 0 and #calls.rules == 0 and #calls.load == 0, "apply only sets values")
check(calls.config[1].plugin.hyprbars.memphis == true and calls.config[1].decoration.rounding == 0, "apply follows memphis")

-- Returning to Platinum resets every style choice, not just the palette.
write_state("platinum", "dark", "on")
fresh_hl(true)
M.apply()
local restored = calls.config[1].plugin.hyprbars
check(restored.memphis == false and restored.bar_text_font == "ChicagoFLF" and restored.bar_height == 20,
    "switching back restores Platinum's font and geometry")

-- A deployed Lua may meet the still-loaded generation-52 plugin. Reject
-- every new option, not just memphis, so attach/apply cannot hide an error.
for _, state in ipairs({ { "memphis", "light", "off" }, { "memphis", "dark", "on" },
    { "platinum", "light", "off" }, { "platinum", "dark", "off" }, { "platinum", "dark", "on" } }) do
    write_state(table.unpack(state))
    fresh_hl(true, { old = true })
    local ok, err = pcall(M.attach, { border_size = 0, rounding = 6 })
    check(ok, "old plugin attach " .. state[1] .. ": " .. tostring(err))
    check(#calls.rejected == 0, "old plugin receives only registered options on attach")
    local cfg = calls.config[#calls.config]
    if state[1] == "memphis" then
        check(cfg and cfg.plugin and cfg.plugin.hyprbars.enabled == false, "old plugin Memphis: no bars")
        check(cfg and cfg.general and cfg.general.border_size == 0 and cfg.decoration.rounding == 6,
            "old plugin Memphis: session edge and rounding")
        check(cfg and cfg.group and cfg.group.groupbar.col.active == "rgba(ffff0066)", "old plugin Memphis: default groupbar")
    else
        check(cfg and cfg.plugin and cfg.plugin.hyprbars.enabled == true and cfg.plugin.hyprbars.memphis == nil,
            "old plugin Platinum: enabled without the new style option")
        check(cfg and cfg.decoration and cfg.decoration.rounding == 0, "old plugin Platinum: square")
        check(cfg and cfg.plugin and cfg.plugin.hyprbars.bar_text_font == "ChicagoFLF" and
            cfg.plugin.hyprbars.bar_height == 20, "old plugin Platinum: original font and height")
    end
    fresh_hl(true, { old = true })
    ok, err = pcall(M.apply)
    check(ok and err == true and #calls.rejected == 0, "old plugin apply " .. state[1] .. " is safe")
end

-- Probe failures and partial implementations must fall back without trying
-- a configuration write. Check every new option is required by the style.
write_state("memphis", "light", "off")
for _, name in ipairs(MEMPHIS_OPTIONS) do
    fresh_hl(true, { missing = name })
    M.apply()
    check(calls.config[1].plugin.hyprbars.enabled == false and calls.config[1].decoration.rounding == 6,
        "missing " .. name .. " falls back to generation-52 Memphis")
end
fresh_hl(true, { probe_throws = true })
check(pcall(M.apply) and calls.config[1].plugin.hyprbars.enabled == false, "a guarded probe failure falls back")
fresh_hl(true)
hl.get_config = nil
check(pcall(M.apply) and calls.config[1].plugin.hyprbars.enabled == false, "a missing query API falls back")
fresh_hl(true)
M.apply()
check(calls.config[1].plugin.hyprbars.memphis == true, "registered false option still enables Memphis support")

-- Motion: both themes cut windows, fades and layers; any other theme gets
-- the session's values back. apply() sets it with or without the plugin.
local function leaves(list)
    local out = {}
    for _, a in ipairs(list) do out[a.leaf] = a end
    return out
end
for _, name in ipairs({ "platinum", "memphis" }) do
    local m = leaves(M.motion({ name = name, mode = "dark", extra = false }))
    for _, leaf in ipairs({ "windows", "fade", "layers" }) do
        check(m[leaf] and m[leaf].enabled == false, name .. ": " .. leaf .. " animation off")
    end
    check(m.workspaces == nil, name .. ": page slides keep the session's value")
end
local back = leaves(M.motion({ name = "unknown", mode = "dark", extra = false }))
check(back.windows.enabled and back.windows.speed == 4 and back.windows.bezier == "quick", "unknown theme: session windows")
check(back.fade.enabled and back.fade.speed == 4 and back.fade.bezier == "quick", "unknown theme: session fade")
check(back.layers.enabled and back.layers.speed == 8 and back.layers.bezier == "default", "unknown theme: Hyprland's layers")
write_state("memphis", "light", "off")
fresh_hl(false)
M.apply()
check(#calls.animation == 3 and leaves(calls.animation).layers.enabled == false, "apply without the plugin still cuts the motion")
write_state("platinum", "dark", "off")
fresh_hl(true)
M.apply()
check(#calls.animation == 3 and leaves(calls.animation).fade.enabled == false, "apply with the plugin cuts the motion")
write_state("unknown", "dark", "off")
fresh_hl(true)
M.apply()
check(M.state().name == "platinum", "unknown saved theme falls back to Platinum without an alias")
check(M.appearance(M.state()) == "dark", "unknown saved theme uses Platinum colours")
check(leaves(calls.animation).windows.enabled == false, "unknown saved theme uses Platinum motion")
write_state("memphis", "dark", "off")
fresh_hl(true, { reject_leaf = "layers" })
check(M.apply_motion() == false and #calls.animation == 2, "a rejected leaf does not stop the others")
fresh_hl(true, { no_animation = true })
check(pcall(M.apply) and M.apply_motion() == false, "no hl.animation: apply still sets the bars")

-- Compare the real QML palette results for every appearance, including
-- Extra dark and light-only Drawing Board. Formatting/aliases in QML do not
-- affect this seam: checks.titlebars obtains this JSON from qmltestrunner.
local kit, _, decode_error = require("dkjson").decode(read_file(palettes_path))
assert(kit, decode_error)
local function same(a, b, what) check(a ~= nil and a == b, what .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function color(p, token)
    local value = p[token]
    assert(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), "Missing/invalid QML colour: " .. token)
    return value:sub(2)
end
for id, appearances in pairs(kit.platinum) do
    for _, extra in ipairs({ false, true }) do
        local state = { name = "platinum", mode = appearances.mode, appearance = id, extra = extra }
        local key = M.appearance(state)
        local p = assert(M.PALETTES[key], id)
        local qml = appearances[extra and "on" or "off"]
        local roles = { face = "menuSurface", text = "menuText", text_off = "menuTextOff",
            hi = "bevelLight", lo = "bevelDark", edge = "menuEdge", box = "raised", rule = "menuEdge" }
        if id == "drawing-board" then
            -- Plain paper caption, without stripes or bevel; boxes use field paper.
            roles.face, roles.hi, roles.lo, roles.box = "titleSurface", "titleSurface", "titleSurface", "field"
        elseif key == "black" then
            roles = { face = "barSurface", text = "barText", text_off = "barTextOff",
                hi = "barSurface", lo = "barSurface", edge = "ridgeLow", box = "barSurface", rule = "barRule" }
        end
        for field, token in pairs(roles) do
            same(p[field], color(qml, token), "Platinum " .. id .. " extra=" .. tostring(extra) .. " " .. field .. " = " .. token)
        end
        local hb = M.settings(state).plugin.hyprbars
        for option, field in pairs({ bar_color = "face", ["col.text"] = "text", platinum_title_inactive = "text_off",
            platinum_hi = "hi", platinum_lo = "lo", platinum_frame = "edge", platinum_box = "box", platinum_rule = "rule" }) do
            same(hb[option], "rgb(" .. p[field] .. ")", "Platinum " .. id .. " setting " .. option)
        end
    end
end
for id, appearances in pairs(kit.memphis) do
    local p = id == "standard" and M.MEMPHIS_PALETTES.light or id == "dark-grey" and M.MEMPHIS_PALETTES.dark or M.SCHEME_PALETTES[id]
    assert(p, id)
    for _, extra in ipairs({ false, true }) do
        local hb = M.settings({ name = "memphis", mode = appearances.mode, appearance = id, extra = extra }).plugin.hyprbars
        local qml = appearances[extra and "on" or "off"]
        for field, token in pairs({ face = "face", hi = "hi", li = "li", lo = "sh", edge = "dk", text = "captionText",
            text_off = "inactiveCaptionText", glyph = "text", caption1 = "caption1", caption2 = "caption2",
            inactive1 = "inactiveCaption1", inactive2 = "inactiveCaption2" }) do
            same(p[field], color(qml, token), "Memphis " .. id .. " " .. token)
        end
        for option, field in pairs({ bar_color = "face", ["col.text"] = "text", platinum_title_inactive = "text_off",
            platinum_hi = "hi", platinum_lo = "lo", platinum_frame = "edge", platinum_box = "face", platinum_rule = "edge",
            memphis_li = "li", memphis_button_text = "glyph", memphis_caption1 = "caption1", memphis_caption2 = "caption2",
            memphis_inactive1 = "inactive1", memphis_inactive2 = "inactive2" }) do
            same(hb[option], "rgb(" .. p[field] .. ")", "Memphis " .. id .. " setting " .. option)
        end
    end
end

-- Every scheme uses its own gradient pair, frame and title text live.
for id, p in pairs(M.SCHEME_PALETTES) do
    local hb = M.settings({ name = "memphis", mode = "light", appearance = id, extra = true }).plugin.hyprbars
    check(hb.memphis_caption1 == "rgb(" .. p.caption1 .. ")", id .. ": active start")
    check(hb.memphis_caption2 == "rgb(" .. p.caption2 .. ")", id .. ": active end")
    check(hb.memphis_inactive1 == "rgb(" .. p.inactive1 .. ")", id .. ": inactive start")
    check(hb.memphis_inactive2 == "rgb(" .. p.inactive2 .. ")", id .. ": inactive end")
    local f = assert(io.open(dir .. "/mountainous/theme-appearance", "w")); f:write(id); f:close()
    write_state("memphis", "light", "on")
    local actual = M.state()
    local dark = id == "high-contrast-black" or id == "high-contrast-1" or id == "high-contrast-2"
    check(actual.appearance == id and actual.mode == (dark and "dark" or "light"), id .. ": derives mode")
end
local f = assert(io.open(dir .. "/mountainous/theme-appearance", "w")); f:write("drawing-board"); f:close()
write_state("platinum", "dark", "on")
check(M.state().mode == "light" and M.appearance(M.state()) == "drawing-board", "Drawing Board ignores Extra dark")
local board = M.settings(M.state()).plugin.hyprbars
check(board.bar_color == "rgb(" .. M.PALETTES["drawing-board"].face .. ")", "Drawing Board paper title bar")
os.remove(dir .. "/mountainous/theme-appearance")

-- hyprland.lua hands the module the values it uses itself.
local hypr = read_file(hyprland_path)
check(hypr:find('require("titlebars").attach({ border_size = BORDER_SIZE, rounding = ROUNDING })', 1, true) ~= nil,
    "hyprland.lua attaches titlebars with its own edge")
check(hypr:find("border_size = BORDER_SIZE,", 1, true) ~= nil and hypr:find("rounding = ROUNDING,", 1, true) ~= nil,
    "hyprland.lua's config uses the same edge")

for leaf, v in pairs({ windows = M.SESSION_MOTION.windows, fade = M.SESSION_MOTION.fade }) do
    local found = false
    for l in hypr:gmatch("[^\n]+") do
        if l:find('hl.animation({ leaf = "' .. leaf .. '",', 1, true) == 1 then
            found = l:gsub("%s+", " ") == 'hl.animation({ leaf = "' .. leaf .. '", enabled = true, speed = '
                .. v.speed .. ', bezier = "' .. v.bezier .. '" })'
        end
    end
    check(found, "hyprland.lua's " .. leaf .. " motion is SESSION_MOTION's")
end
check(hypr:find('leaf = "layers"', 1, true) == nil, "hyprland.lua leaves layers to Hyprland's global (SESSION_MOTION.layers)")

check(hypr:find('hl.bind("ALT + Space"', 1, true) ~= nil and
    hypr:find("windows menu '' -1 -1", 1, true) ~= nil, "Alt+Space routes to the shared window menu")

os.execute("rm -rf " .. dir)
if failures > 0 then
    io.stderr:write(failures .. " titlebars check(s) failed\n")
    os.exit(1)
end
print("titlebars: appearances, settings, motion, attach, apply, tokens pass")
