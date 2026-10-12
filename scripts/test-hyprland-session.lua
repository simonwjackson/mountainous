-- Run by scripts/test-hyprland-session. Loads the real hyprland.lua and
-- session modules against scripts/lib/hypr-model.lua.
local ROOT = assert(os.getenv("MOUNTAINOUS_ROOT"))
local STATE = assert(os.getenv("XDG_STATE_HOME")) .. "/mountainous/session/snapshot.lua"
local HYPR = ROOT .. "/modules/hyprland/"
package.path = ROOT .. "/scripts/lib/?.lua;" .. package.path
local Model = require("hypr-model")
local TERM = "io.github.simonwjackson.mountainous.term"
local passed = 0

local function check(cond, message)
    if not cond then error(message, 2) end
    passed = passed + 1
end

local function same(a, b, message)
    local function show(t)
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. tostring(t[k]) end
        return "{" .. table.concat(out, " ") .. "}"
    end
    check(show(a) == show(b), message .. ": got " .. show(a) .. ", want " .. show(b))
end

-- Boots the config into a fresh model, as a new login does.
local function boot(with_session, cmdlines)
    for name in pairs(package.loaded) do
        if name:match("^session") then package.loaded[name] = nil end
    end
    local m = Model.new()
    _G.hl = m.hl
    local base = ROOT .. "/scripts/lib/?.lua;./?.lua"
    package.path = with_session and (HYPR .. "?.lua;" .. base) or base
    if with_session then
        local restore = require("session-restore")
        restore.read_cmdline = function(pid) return cmdlines and cmdlines[pid] end
        restore.installed = function(name) return name == "zed-editor" end
    end
    dofile(HYPR .. "hyprland.lua")
    m:emit("hyprland.start")
    return m
end

local function file()
    local f = io.open(STATE, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

-- ---------------------------------------------------------------- plan
local plan = dofile(HYPR .. "session-plan.lua")
check(plan.quote("zeditor") == "zeditor", "safe words stay bare")
check(plan.quote("a b'c") == "'a b'\\''c'", "unsafe words are single-quoted")
same(plan.split_cmdline("/x/chromium --a=1 --b"), { "/x/chromium", "--a=1", "--b" }, "one-field Chromium cmdline splits")
same(plan.split_cmdline("ghostty\0--class=t\0-e\0herdr\0"), { "ghostty", "--class=t", "-e", "herdr" }, "NUL cmdline splits")
local never = function() return false end
check(plan.launch_command("chrome-app.test__-Default", { "/nix/store/x-chromium-unwrapped-1/libexec/chromium/chromium", "--app=https://app.test/" }, never)
    == "web-app https://app.test/", "a Chromium app window relaunches through web-app")
check(plan.launch_command("chromium-browser", { "/nix/store/x-chromium-unwrapped-1/libexec/chromium/chromium", "--flag" }, never)
    == "chromium --flag", "a browser window relaunches through the chromium wrapper")
check(plan.launch_command("dev.zed.Zed", { "/nix/store/z/libexec/zed-editor", "x" }, never) == "zeditor", "Zed relaunches through its launcher")
check(plan.launch_command("x", { "/nix/store/a/bin/tool", "-v" }, function(n) return n == "tool" end) == "tool -v",
    "a store path becomes its installed name, which survives garbage collection")
check(plan.launch_command("x", { "/nix/store/a/bin/tool" }, never) == "/nix/store/a/bin/tool", "an uninstalled store path is kept")
check(plan.regex_escape("a.b-c") == "a\\.b\\-c", "class regex escapes metacharacters")
local snap = { windows = { { title = "one" }, { title = "two" }, { title = "three" } } }
local paired = plan.pair(snap, { 1, 2, 3 }, { { address = "B", title = "two" }, { address = "X", title = "?" }, { address = "A", title = "one" } })
check(paired[1].address == "A" and paired[2].address == "B" and paired[3].address == "X", "pair by title first, then arrival")
same(plan.order_swaps({ "a", "b", "c" }, { "c", "a", "b" })[1], { "c", "a" }, "order swaps start at the first wrong position")
check(#plan.order_swaps({ "a", "b" }, { "a", "b" }) == 0, "a correct page needs no swaps")
local captured = plan.capture({
    { class = "c", title = "t", pid = 1, ws_id = 5, floating = false, at = { 0, 0 }, size = { 1, 1 }, command = "c" },
    { class = "c", title = "u", pid = 1, ws_id = 5, floating = false, at = { 960, 0 }, size = { 1, 1 }, command = "c" },
}, {}, 1)
check(captured.pages[1].capacity == 2 and captured.windows[1].page == 1, "a page holding two tiled windows keeps room for two")
check(captured.windows[1].spawn and not captured.windows[2].spawn, "one launch per process and class")
check(plan.decode("return " .. plan.serialize(captured)).windows[2].title == "u", "serialize and decode round-trip")
check(plan.decode("os.exit(1)") == nil and plan.decode("return 1") == nil, "decode rejects anything but a snapshot")
check(plan.capture({}, {}, 1) == nil, "an empty desktop captures nothing")
local right = plan.capture({
    { class = "s", title = "s", pid = 1, ws_id = 1, at = { 0, 0 }, size = { 1, 1 }, master = false },
    { class = "m", title = "m", pid = 2, ws_id = 1, at = { 733, 0 }, size = { 1, 1 }, master = true, ratio = 0.6180300116539 },
    { class = "o", title = "o", pid = 3, ws_id = 2, at = { 0, 0 }, size = { 1, 1 }, master = true, ratio = 0.5 },
}, {}, 1)
check(right.pages[1].side == "right" and right.pages[1].ratio == 0.61803, "a page records its master side and rounded split")
check(right.pages[2].side == nil and right.pages[2].ratio == nil, "a one-window page has no split to record")
local defaults = { side = "left", ratio = 0.5 }
check(#plan.layout_messages({ side = "left", ratio = 0.5 }, defaults) == 0, "a default page needs no messages")
same(plan.layout_messages({ side = "right", ratio = 0.61803 }, defaults),
    { "orientationright", "mfact exact 0.61803" }, "a changed page gets its side and split")

-- ------------------------------------------------------ Super+G, per page
local sp = boot(false)
local a1 = sp:map("a", "a1"); sp:press("SUPER + 2"); sp:map("a", "a2")
sp.hl.dispatch(sp.hl.dsp.focus({ workspace = 2 }))
local b1 = sp:map("b", "b1"); sp:press("SUPER + 2"); sp:map("b", "b2")
local function super_g(w)
    sp.hl.dispatch(sp.hl.dsp.focus({ window = "address:" .. w.address }))
    dofile(HYPR .. "hypr-split.lua")
end
super_g(a1)
super_g(b1)
check(sp:workspace(1).mfact == 0.61803 and sp:workspace(2).mfact == 0.61803, "Super+G turns each even page golden")
super_g(b1)
check(sp:workspace(2).mfact == 0.5 and sp:workspace(1).mfact == 0.61803, "Super+G toggles only the focused page")

-- ---------------------------------------------------------- host without it
local plain = boot(false)
check(plain.handlers["hyprland.start"] == nil or #plain.handlers["hyprland.start"] == 0, "hosts without the module load no session code")

-- ------------------------------------------------------ capacity follows ids
local m = boot(true)
m:map("a", "a1")
m.hl.dispatch(m.hl.dsp.focus({ workspace = 2 })); m:map("b", "b1")
m.hl.dispatch(m.hl.dsp.focus({ workspace = 3 })); m:map("c", "c1")
m:press("SUPER + 2"); m:map("c", "c2")
check(m:where().c2 == "3", "capacity two keeps a second window on its page")
m.hl.dispatch(m.hl.dsp.focus({ workspace = 1 }))
m:close(m.windows[2])
check(m:where().c1 == "2" and m:where().c2 == "2", "the strip closes the gap")
m.hl.dispatch(m.hl.dsp.focus({ workspace = 2 })); m:map("c", "c3")
check(m:where().c3 ~= "2" and m:where().c2 == "2", "capacity followed the page to its new id")

-- ----------------------------------------------- reload keeps a full page
local reload = boot(true)
reload:map("a", "a1"); reload:press("SUPER + 2"); reload:map("a", "a2")
for name in pairs(package.loaded) do if name:match("^session") then package.loaded[name] = nil end end
reload:reset_config()
dofile(HYPR .. "hyprland.lua")
reload:map("a", "a3")
check(reload:where().a1 == "1" and reload:where().a2 == "1" and reload:where().a3 ~= "1", "a reload does not split a full page")

-- ------------------------------------------------------------------ save
os.remove(STATE)
local cmd = {
    [10] = "/nix/store/z/libexec/zed-editor\0x\0",
    [20] = "/nix/store/c-chromium-unwrapped-1/libexec/chromium/chromium --app=https://forge.test/ --user-data-dir=/p",
    [30] = "/nix/store/c-chromium-unwrapped-1/libexec/chromium/chromium --flag",
    [40] = "ghostty\0--class=term\0-e\0herdr\0",
}
local s = boot(true, cmd)
s:map("dev.zed.Zed", "one", 10); s:press("SUPER + 2"); s:map("dev.zed.Zed", "two", 10)
s.hl.dispatch(s.hl.dsp.focus({ workspace = 2 })); s:map("chrome-forge.test__-Default", "forge", 20)
s.hl.dispatch(s.hl.dsp.focus({ workspace = 3 })); s:map("chromium-browser", "web", 30)
local term = s:map(TERM, "herdr", 40)
check(term.floating, "the overlay's own rule floats it")
s:place(term, s:workspace("special:term"))
s.hl.dispatch(s.hl.dsp.focus({ workspace = 1 }))
s:advance(10000)
check(file() == nil, "one capture is not enough to write")
s:advance(10000)
local saved = assert(plan.decode(file() or ""), "two equal captures write the snapshot")
check(saved.pages[1].capacity == 2 and #saved.pages == 3, "pages and capacity are saved")
check(saved.pages[1].side == "left" and saved.pages[1].ratio == 0.5, "the two-window page saves its split")
local by = {}
for _, w in ipairs(saved.windows) do by[w.title] = w end
check(by.one.command == "zeditor" and by.one.spawn and not by.two.spawn, "Zed launches once")
check(by.forge.command == "web-app https://forge.test/" and by.forge.page == 2, "the PWA is saved with its launcher")
check(by.web.command == "chromium --flag" and by.web.page == 3, "the browser is saved with the wrapper")
check(by.herdr.special == "special:term" and by.herdr.command == "ghostty --class=term -e herdr", "the overlay is saved by name")
local good = file()
for i = #s.windows, 1, -1 do s:close(s.windows[i]); s:advance(1500) end
s:advance(60000)
check(file() == good, "windows closing at shutdown never replace the snapshot")

-- --------------------------------------------------------------- restore
local r = boot(true, cmd)
-- Apps answer launches late and in the wrong order, as Zed does while it
-- waits for SSH: its second window first.
r.pending = {}
r.after = function(self)
    for i = #self.launches, 1, -1 do
        local c = table.remove(self.launches, i)
        local at = self.now
        if c == "zeditor" then
            table.insert(self.pending, { at + 40000, "dev.zed.Zed", "two", 10 })
            table.insert(self.pending, { at + 41000, "dev.zed.Zed", "one", 10 })
        elseif c:match("^web%-app") then table.insert(self.pending, { at + 1000, "chrome-forge.test__-Default", "forge", 20 })
        elseif c:match("^chromium") then table.insert(self.pending, { at + 1500, "chromium-browser", "web", 30 })
        elseif c:match("^ghostty") then table.insert(self.pending, { at + 500, TERM, "herdr", 40 }) end
    end
end
-- You look at the browser while Zed is still connecting. Page 1 is empty
-- and you walked away, so it is destroyed; the strip must not renumber
-- pages 2 and 3 under the windows still aimed at them.
r.hl.timer(function() r.hl.dispatch(r.hl.dsp.focus({ workspace = 2 })) end, { timeout = 10000, type = "oneshot" })
r.hl.timer(function()
    for i = #r.pending, 1, -1 do
        if r.pending[i][1] <= r.now then
            local p = table.remove(r.pending, i)
            r:map(p[2], p[3], p[4])
        end
    end
end, { timeout = 250, type = "repeat" })
r:advance(120000)
same(r:where(), { one = "1", two = "1", forge = "2", web = "3", herdr = "special:term" }, "every window returns to its page")
local first = {}
for _, w in ipairs(r.windows) do first[w.title] = w.first_workspace end
same(first, { one = "1", two = "1", forge = "2", web = "3", herdr = "special:term" }, "rules place windows as they open")
local page1 = r:workspace(1).list
check(page1[1].title == "one" and page1[2].title == "two", "the page keeps its saved order after late, reversed arrival")
check(#r.notes == 0, "a complete restore shows no notification")
r:advance(30000)
check(file() == good, "the restored desktop saves as the same snapshot")
r.hl.dispatch(r.hl.dsp.focus({ workspace = 1 }))
r:map("x", "third")
check(r:where().one == "1" and r:where().two == "1" and r:where().third ~= "1",
    "page 1 keeps its restored capacity of two")

-- ------------------------------------- one class across pages, reversed
local function write_snapshot(snapshot)
    local f = assert(io.open(STATE, "wb"))
    f:write("return " .. plan.serialize(snapshot) .. "\n")
    f:close()
end
local function zed(title, page, spawn)
    return { class = "dev.zed.Zed", title = title, page = page, floating = false, pinned = false,
             fullscreen = 0, at = { 0, 0 }, size = { 800, 600 }, command = "zeditor", spawn = spawn }
end
write_snapshot({ version = 1, pages = { { capacity = 1 }, { capacity = 1 } },
                 windows = { zed("one", 1, true), zed("two", 2, false) } })
local x = boot(true)
x.after = function(self)
    for i = #self.launches, 1, -1 do
        if table.remove(self.launches, i) == "zeditor" then
            self:map("dev.zed.Zed", "two"); self:map("dev.zed.Zed", "one")
        end
    end
end
x:advance(20000)
local landed = {}
for _, w in ipairs(x.windows) do landed[#landed + 1] = w.first_workspace end
same(landed, { "1", "2" }, "each window of one class opens on its own page")
same(x:where(), { one = "1", two = "2" }, "titles put reversed windows back on their pages")
write_snapshot(plan.decode(good))

-- ------------------------------------------ a mirrored, golden page
write_snapshot({ version = 1,
    pages = { { capacity = 1 }, { capacity = 2, side = "right", ratio = 0.61803 } },
    windows = {
        { class = "x", title = "a", page = 1, floating = false, pinned = false, fullscreen = 0,
          at = { 0, 0 }, size = { 800, 600 }, command = "x-app", spawn = true },
        zed("two", 2, true), zed("one", 2, false),
    } })
local y = boot(true)
y.after = function(self)
    for i = #self.launches, 1, -1 do
        local c = table.remove(self.launches, i)
        if c == "x-app" then self:map("x", "a")
        elseif c == "zeditor" then self:map("dev.zed.Zed", "two"); self:map("dev.zed.Zed", "one") end
    end
end
local y_start = y.active
y:advance(20000)
same(y:where(), { a = "1", two = "2", one = "2" }, "the mirrored page's windows return")
local page2 = y:workspace(2)
check(page2.side == "right" and page2.mfact == 0.61803, "the page gets its saved side and split")
check(page2.list[1].title == "one", "the saved master is master again")
check(y.active == y_start, "you are returned to the page you started on")
y:advance(30000)
local again = plan.decode(file() or "")
check(again and again.pages[2].side == "right" and again.pages[2].ratio == 0.61803,
    "the restored page saves the same side and split")
write_snapshot(plan.decode(good))

-- ------------------------------------------------------------- a gap
local g = boot(true)
g.after = function(self)
    for i = #self.launches, 1, -1 do
        local c = table.remove(self.launches, i)
        if c == "zeditor" then g:map("dev.zed.Zed", "one"); g:map("dev.zed.Zed", "two")
        elseif c:match("^web%-app") then g:map("chrome-forge.test__-Default", "forge")
        elseif c:match("^ghostty") then g:map(TERM, "herdr") end
    end
end
g:advance(400000)
same(g:where(), { one = "1", two = "1", forge = "2", herdr = "special:term" }, "a window that never opens leaves no hole")
check(#g.notes == 1 and g.notes[1]:match("chromium%-browser"), "the missing window is reported")
local late = g:map("chromium-browser", "late")
check(late.first_workspace == g.active.name, "rules are off once restore ends")

-- ------------------------------------------------------ populated desktop
local p = boot(true)
p:map("x", "already open")
p:advance(5000)
check(#p.launches == 0, "a populated desktop is left alone")

-- ------------------------------------------- a second monitor below
-- The tablet attaches as SUNSHINE (modules/second-screen.py). Each screen
-- walks its own pages, and pages are numbered across both.
local s = boot(true)
s:map("a", "a1")
s.hl.dispatch(s.hl.dsp.focus({ workspace = 2 })); s:map("b", "b1")
s.hl.dispatch(s.hl.dsp.focus({ workspace = 1 }))
local tablet = s:add_monitor("SUNSHINE")
same(s:pages("SUNSHINE"), { "3" }, "the tablet starts on one empty page")
check(s.active.monitor.name == "eDP-1", "attaching the tablet leaves focus on the laptop")
s:map("a", "a2")
check(s:where().a2 == "4" and s:workspace(4).monitor.name == "eDP-1",
    "overflow skips the tablet's empty page and stays on the laptop")

s.hl.dispatch(s.hl.dsp.focus({ workspace = 3 })); local t1 = s:map("t", "t1")
check(t1.workspace.monitor == tablet, "a window opened on the tablet stays there")
s:close(t1)
check(s.active.name == "3" and s.active.monitor == tablet,
    "closing the tablet's last window keeps focus on the tablet")

s:close(s.windows[2]) -- b1, page 2
same(s:pages("eDP-1"), { "1", "2" }, "the laptop's pages close the gap")
same(s:pages("SUNSHINE"), { "3" }, "the tablet's empty page keeps its id")
local renamed_onto_held = false
for _, ws in pairs(s.ws) do
    if ws.id == 3 and ws.monitor ~= tablet then renamed_onto_held = true end
end
check(not renamed_onto_held, "no laptop page was renamed onto the tablet's page")

s:map("t", "t2")
s:remove_monitor("SUNSHINE")
same(s:pages("eDP-1"), { "1", "2", "3" }, "detaching folds the tablet's pages onto the laptop")
check(s:where().t2 == "3" and s.windows[#s.windows].workspace.monitor.name == "eDP-1",
    "the tablet's window is on the laptop, on the last page")

-- A reload drops rules made by eval. The module re-applies the client's
-- rule from the runtime file, so the monitor stays under the panel.
local STATE_RULE = assert(os.getenv("XDG_RUNTIME_DIR")) .. "/mountainous-second-screen.lua"
local r2 = boot(true)
check(r2.monitor_rules.SUNSHINE == nil, "no client, no rule")
check(r2.devices["libvirtualhid-touchscreen"].output == "SUNSHINE"
    and r2.devices["libvirtualhid-pen-tablet"].output == "SUNSHINE", "touch and pen map to the tablet")
local f = assert(io.open(STATE_RULE, "wb"))
f:write('return { output = "SUNSHINE", mode = "2960x1848@60", position = "35x1200", scale = "1.600000" }\n')
f:close()
r2:reset_config()
dofile(HYPR .. "hyprland.lua")
check(r2.monitor_rules.SUNSHINE ~= nil and r2.monitor_rules.SUNSHINE.position == "35x1200",
    "a reload re-applies the client's monitor rule")
check(require("second-screen").apply(), "apply reports the rule it applied")
os.remove(STATE_RULE)
check(not require("second-screen").apply(), "apply does nothing once the client has gone")

print(string.format("HYPRLAND_SESSION_TESTS_OK %d checks", passed))
