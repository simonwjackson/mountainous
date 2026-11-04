-- Run the real Ctrl+L callback without a compositor. A non-browser must
-- return ok=false, not send a second synthetic key through a dispatcher.
local file = assert(io.open(arg[1], "r"))
local source = file:read("*a")
file:close()
local binding = assert(source:match('(hl%.bind%("CTRL %+ L".-)\n\n'))
local callback, options, active, commands
hl = {
    bind = function(_, cb, opts) callback, options = cb, opts end,
    get_active_window = function() return active end,
    exec_cmd = function(command) commands[#commands + 1] = command end,
    dispatch = function() error("Ctrl+L must use auto_consuming, not synthetic pass") end,
}
assert(load(binding))()
assert(options and options.auto_consuming, "Ctrl+L must explicitly consume only browser keys")
for _, class in ipairs({ "chromium", "chromium-browser", "Chromium", "chrome-example.com__-Default", "chrome-extensionid-Profile_1" }) do
    active, commands = { class = class, address = "123" }, {}
    assert(callback().ok == true, class .. " must consume Ctrl+L")
    assert(#commands == 1 and commands[1] == "qs -c mountainous ipc call omni navigate")
end
for _, class in ipairs({ "ghostty", "org.gnome.TextEditor", "chromium-editor", "", "com.google.Chrome" }) do
    active, commands = { class = class, address = "123" }, {}
    assert(callback().ok == false, class .. " must keep its own Ctrl+L")
    assert(#commands == 0)
end
active, commands = nil, {}
assert(callback().ok == false)
assert(#commands == 0)
local getenv = os.getenv
os.getenv = function(name) if name == "MOUNTAINOUS_BROWSER_INTEGRATION" then return "0" end; return getenv(name) end
active, commands = {class = "chromium-browser"}, {}
assert(callback().ok == false and #commands == 0, "rollback returns normal Chromium's Ctrl+L")
active = {class = "chrome-site.test__-Default"}
assert(callback().ok == true, "rollback keeps the pre-existing web-app shortcut")
os.getenv = getenv
print("browser keys: normal, popup, app, non-browser and no-window Ctrl+L pass")

-- The real fake-fullscreen rule and Super+U callback. LuaWindow exposes
-- fullscreen_client (snake_case), not hyprctl JSON's fullscreenClient.
local section = assert(source:match('%-%- CHROMIUM PAGE FRAME\n(.-)\n%-%-%-%-'))
local rules, toggle, states
hl = {
    window_rule = function(rule) rules[#rules + 1] = rule end,
    bind = function(key, cb) assert(key == "SUPER + U"); toggle = cb end,
    get_active_window = function() return active end,
    dsp = { window = { fullscreen_state = function(state) return state end } },
    dispatch = function(state) states[#states + 1] = state; active.fullscreen_client = state.client end,
}
local function configure(text)
    rules, toggle, states = {}, nil, {}
    assert(load('local mod = "SUPER"\n' .. text))()
end
configure(section)
assert(#rules == 1 and rules[1].match.class == "^(chromium-browser|chromium|chrome-.*)$")
assert(rules[1].fullscreen_state == "0 2" and rules[1].suppress_event == "fullscreen")
for _, class in ipairs({ "chromium", "chromium-browser", "chrome-example.com__-Default", "chrome-appid-Default" }) do
    active, states = { class = class, fullscreen_client = 2 }, {}
    toggle()
    assert(#states == 1 and states[1].internal == 0 and states[1].client == 0, "Super+U reveals " .. class .. " UI without compositor fullscreen")
    toggle()
    assert(#states == 2 and states[2].internal == 0 and states[2].client == 2, "Super+U hides " .. class .. " UI again")
    assert(states[1].window == nil and states[2].window == nil, "only the active window is targeted")
end
for _, class in ipairs({ "ghostty", "Chromium", "chromium-editor", "not-chrome-appid", "com.google.Chrome", "" }) do
    active, states = { class = class, fullscreen_client = 2 }, {}
    toggle()
    assert(#states == 0, class .. " must not change fullscreen state")
end
active, states = {}, {}
toggle()
active = nil
toggle()
assert(#states == 0, "missing class/window is safe")
configure((section:gsub('local CHROMIUM_FAKE_FULLSCREEN = true', 'local CHROMIUM_FAKE_FULLSCREEN = false', 1)))
assert(#rules == 0 and toggle == nil, "local flag disables the rule and toggle")
print("browser frame: fake fullscreen and active-window Super+U toggle pass")
