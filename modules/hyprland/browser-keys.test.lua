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
