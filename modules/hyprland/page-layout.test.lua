-- Headless compositor adapter. Dispatch changes the same live objects the
-- queries return, including synchronous move events and deferred timers.
local module_path, output_path, config_path = arg[1], arg[2], arg[3]
local json = require("dkjson")
local dir = os.tmpname()
os.remove(dir)
assert(os.execute("mkdir -p " .. dir .. "/mountainous"))
local getenv = os.getenv
os.getenv = function(key)
    if key == "XDG_STATE_HOME" or key == "XDG_RUNTIME_DIR" then return dir end
    return getenv(key)
end
local function read(path)
    local f = assert(io.open(path)); local text = f:read("*a"); f:close(); return text
end
local function check(value, message) assert(value, message) end
local monitors = {
    { name = "eDP-1", description = 'Built-in "Display"', width = 2880, height = 1800, scale = 1.5, focused = true },
    { name = "DP-1", description = "", width = 1200, height = 1920, scale = 1, focused = false },
}
local spaces, windows, events, timers, rules, moves = {}, {}, {}, {}, {}, {}
local focused, reject_dispatch, on_focus
local function emit(name, ...)
    for _, callback in ipairs(events[name] or {}) do callback(...) end
end
local function flush()
    local count = 0
    while #timers > 0 do
        count = count + 1; assert(count < 100, "timer/event loop")
        local batch = timers; timers = {}
        for _, t in ipairs(batch) do if t.enabled then t.callback() end end
    end
end
local function ws(id, monitor)
    local w = { id = id, special = id < 0, monitor = monitor or monitors[1], windows = 0 }
    function w:get_windows()
        local out = {}
        for _, win in ipairs(windows) do if win.workspace == self then out[#out + 1] = win end end
        return out
    end
    -- Workspace::init emits created before CWorkspace::create registers it.
    emit("workspace.created", w)
    spaces[#spaces + 1] = w
    return w
end
local function by_id(id)
    for _, w in ipairs(spaces) do if w.id == id then return w end end
end
local function by_address(selector)
    local address = assert(selector:match("^address:(.+)$"))
    for _, w in ipairs(windows) do if w.address == address then return w end end
    error("window missing: " .. selector)
end
local function win(id, page, floating, pinned, open)
    local w = { address = tostring(id), workspace = page, floating = floating or false, pinned = pinned or false }
    windows[#windows + 1] = w; page.windows = page.windows + 1
    if open then emit("window.open", w); flush() end
    return w
end
local function move(w, page)
    w.workspace.windows = w.workspace.windows - 1
    w.workspace = page; page.windows = page.windows + 1
    emit("window.move_to_workspace", w, page)
end
local function remove(page)
    for i, p in ipairs(spaces) do if p == page then table.remove(spaces, i); break end end
    emit("workspace.removed", page)
end
local function dispatcher(kind)
    return function(args) return { kind = kind, args = args } end
end
_G.hl = {
    get_workspaces = function() return spaces end,
    get_windows = function() return windows end,
    get_monitors = function() return monitors end,
    get_active_workspace = function() return monitors[1].active_workspace end,
    get_active_window = function() return focused end,
    on = function(name, callback)
        events[name] = events[name] or {}; table.insert(events[name], callback)
    end,
    timer = function(callback, _)
        local t = { callback = callback, enabled = true }
        function t:set_enabled(value) self.enabled = value end
        timers[#timers + 1] = t; return t
    end,
    workspace_rule = function(spec)
        assert(type(spec.workspace) == "string", "real API needs a string selector")
        local rule = rules[spec.workspace]
        if not rule or not rule.enabled then
            rule = { enabled = true }; rules[spec.workspace] = rule
            function rule:set_enabled(value) self.enabled = value end
        end
        rule.gaps_out = spec.gaps_out
        return rule
    end,
    dsp = { focus = dispatcher("focus"), window = { float = dispatcher("float"), move = dispatcher("move") },
        workspace = { change_id = dispatcher("change_id") } },
    dispatch = function(d)
        if d.kind == reject_dispatch then return { ok = false, error = "configured dispatch rejection" } end
        local a = d.args
        if d.kind == "float" then
            assert(a.action == "on" or a.action == "off" or a.action == "toggle", "real API float action is on/off/toggle, not set/unset")
            local w = by_address(a.window)
            if a.action == "toggle" then
                local provenance = json.decode(read(dir .. "/mountainous-page-layout-floated.json"))
                check(provenance[w.address] == nil, "manual float ownership is persisted before dispatch")
                w.floating = not w.floating
            else w.floating = a.action == "on" end
        elseif d.kind == "focus" then
            if a.window then focused = by_address(a.window)
            else monitors[1].active_workspace = assert(by_id(a.workspace)) end
            if on_focus then on_focus() end
        elseif d.kind == "move" then
            local page = by_id(a.workspace) or ws(a.workspace, focused.workspace.monitor)
            moves[#moves + 1] = { address = focused.address, target = page.id }
            move(focused, page)
        elseif d.kind == "change_id" then
            assert(not by_id(a.id), "renumber collision")
            assert(by_id(a.workspace)).id = a.id
        else error("unexpected dispatch: " .. d.kind) end
        return { ok = true }
    end,
}
local M = dofile(module_path).attach()
check(read(M.FILE):match('"pages":{}'), "no pages encodes an object, not an array")
local p1, p2 = ws(1), ws(2, monitors[2])
monitors[1].active_workspace, monitors[2].active_workspace = p1, p2
flush()
check(json.decode(read(M.FILE)).pages["1"] and json.decode(read(M.FILE)).pages["2"], "created pages appear after registration without another event")
check(rules["2"] and rules["2"].gaps_out == 8, "latest created empty page gets its gap rule after registration")
local function page(id) return M.snapshot().pages[tostring(id)] end
check(page(1).cap == 1 and page(1).gap == 8 and not page(1).floating, "fallback")
check(not page(1).own, "new page follows default")
check(json.decode(read(M.FILE)).version == 1, "state written at load")
check(rules["1"].gaps_out == 8, "workspace outer gap at load")

M.default("eDP-1", { cap = 2, floating = false, gap = 16 })
M.default("DP-1", { cap = 3, floating = true, gap = 24 })
check(page(1).cap == 1 and page(1).own, "default edits do not change existing pages; own is derived")
local persisted = json.decode(read(M.DEFAULTS_FILE))
check(persisted['Built-in "Display"'].cap == 2 and persisted["DP-1"].floating, "description key with connector fallback persists JSON")
local p8, p9 = ws(8), ws(9, monitors[2])
flush()
check(json.decode(read(M.FILE)).pages["8"].gap == 16 and rules["8"].gaps_out == 16, "created page publishes monitor default gap")
check(page(8).cap == 2 and page(8).gap == 16 and not page(8).own, "new page gets monitor default")
check(page(9).floating and page(9).cap == 3, "independent monitor defaults")

-- Cap and newest-first overflow; an empty second-monitor page is reserved.
M.page(1, { cap = 3 })
local a, b, c = win("a", p1), win("b", p1), win("c", p1)
M.page(1, { cap = 1, gap = 12, zen = true })
flush()
check(#p1:get_windows() == 1 and a.workspace == p1, "cap retains oldest/master")
check(moves[1].address == "c" and moves[1].target == 10 and moves[2].address == "b" and moves[2].target == 11, "overflow uses fresh pages newest first")
check(p2.id == 2 and p2.windows == 0, "empty monitor page is not an overflow destination")
check(c.workspace.id == 3 and b.workspace.id == 4, "overflow compacted around reserved pages")
check(page(3).cap == 2 and page(3).gap == 16, "overflow takes monitor default")
check(rules["1"].gaps_out.left == 230 and rules["1"].gaps_out.top == 60, "zen uses logical dimensions")

-- Renumber a configured occupied page; empty pages continue to reserve ids.
M.page(p8.id, { cap = 3, floating = true, gap = 36, zen = true })
local d = win("d", p8, false, false, true)
M.compact(); flush()
check(p8.id == 5 and page(5).cap == 3 and page(5).floating and page(5).gap == 36 and page(5).zen, "all settings follow renumbering")
check(not page(8) and not rules["8"].enabled and rules["5"].enabled, "old page/rule retired and new rule applied")
check(d.floating, "page floated window before renumber")
M.page(5, { floating = false, zen = false })
check(not d.floating and rules["5"].gaps_out == 36, "float ownership and ordinary gaps follow renumbering")
M.page(5, { floating = true })
focused = d
M.toggle_window_floating()
check(not d.floating, "manual toggle tiles a page-floated window")
M.toggle_window_floating()
check(d.floating, "manual toggle refloats the same window")
-- Verify persistence too: a reload must not restore the discarded ownership.
flush()
events = {}
M = dofile(module_path).attach()
M.page(5, { floating = false })
check(d.floating, "manual refloat stays floating when page returns to tiled, including after reload")

-- Page floating has no capacity. Pre-existing hand floaters and pins survive.
M.page(1, { zen = false, floating = true })
local manual = win("manual", p1, true, false, true)
local pinned = win("pinned", p1, true, true, true)
local fresh = win("fresh", p1, false, false, true)
local moved = win("moved", p8)
move(moved, p1); flush()
check(a.floating and fresh.floating and moved.floating and #p1:get_windows() == 5, "floating covers open/moved windows and skips cap")
M.page(1, { cap = 3, floating = false })
flush()
check(not a.floating and not fresh.floating and not moved.floating, "page-floated windows retile")
check(manual.floating and pinned.floating, "hand-floated/pinned windows stay floating")
M.page(1, { floating = true })
a.pinned = true
M.page(1, { floating = false })
check(a.floating, "pinning a page-floated window preserves it")
a.pinned = false

M.page(1, { gap = -8 }); check(page(1).gap == 0, "lower gap clamp")
M.page(1, { gap = 999 }); check(page(1).gap == 48, "upper gap clamp")
M.page(1, { gap = 10 }); check(page(1).gap == 12, "gap rounds to four")
M.step_gap("active", -100); check(page(1).gap == 0, "step gap clamps")
M.step_gap(1, 4); check(page(1).gap == 4, "step gap")
M.page_default(1, "all")
flush()
check(page(1).cap == 2 and page(1).gap == 16 and not page(1).own, "use default all")
M.toggle_zen(1)
check(page(1).zen and not page(1).own, "zen does not make own")
M.toggle_zen(1)
check(rules["1"].gaps_out == 16, "zen off restores page gap")
M.page_default(9, "gap")
M.toggle_zen(9)
check(rules["9"].gaps_out.left == 144 and rules["9"].gaps_out.top == 96, "zen portrait dimensions")
M.reset("DP-1")
check(not page(9).zen and not page(9).own and not page(2).own, "reset every page on one monitor and clear zen")
check(page(1).gap == 16, "reset leaves other monitor alone")
monitors[1].focused, monitors[2].focused = false, true
monitors[2].active_workspace = p9
M.step_gap("active", 4)
check(page(9).gap == 28 and page(1).gap == 16, "active targets focused monitor, not global workspace query")
M.page_default("active", "gap")
monitors[1].focused, monitors[2].focused = true, false

for _, request in ipairs({
    function() M.page(1, { cap = 4 }) end,
    function() M.page(1, { floating = "false" }) end,
    function() M.page(1, { gap = 0/0 }) end,
    function() M.page(1, { typo = true }) end,
    function() M.default("DP-1", { zen = true }) end,
    function() M.default("missing", { cap = 2 }) end,
    function() M.page(999, { cap = 2 }) end,
    function() M.page_default(1, "zen") end,
}) do check(not pcall(request), "invalid request must fail") end

-- The compatibility view used by session-restore shares the real store.
M.hold(true)
M.capacity[41] = 3
M.capacity[40] = 2
local p40 = ws(40)
check(page(40).cap == 2, "restore capacity waits for page creation")
M.capacity[1] = 3
check(page(1).cap == 3 and M.capacity[1] == 3, "restore writes shared capacity")
M.compact(); check(p40.id == 40, "restore holds compaction")
M.hold(false)
local absent_restore = ws(41)
check(page(41).cap == 2, "missing restore page does not override future default")
remove(absent_restore)
M.refresh()
remove(p40)
check(not json.decode(read(M.FILE)).pages["40"], "removed page disappears from file")

-- Reload the module like a new config Lua state; state and provenance are
-- read from the real JSON files, not injected into module internals.
M.page(1, { cap = 3, floating = true, gap = 20, zen = true })
flush()
local before = page(1)
events = {}
M = dofile(module_path).attach()
check(page(1).cap == before.cap and page(1).gap == 20 and page(1).zen and page(1).floating, "page state survives reload")
M.page(1, { floating = false })
flush()
check(not fresh.floating and manual.floating, "float provenance survives reload")
local later = ws(80)
check(page(80).cap == 2 and page(80).gap == 16, "per-monitor defaults survive reload")
-- Same description at another connector keeps its default.
monitors[1].name = "DP-4"
local reconnected = ws(81)
check(page(81).cap == 2 and M.snapshot().defaults["DP-4"].gap == 16, "description follows connector change")
monitors[1].width, monitors[1].height = 1800, 2880
emit("monitor.layout_changed")
check(rules["1"].gaps_out.top == 96 and rules["1"].gaps_out.left == 144, "zen recomputes on monitor layout change")
monitors[1].width, monitors[1].height, monitors[1].transform = 2880, 1800, 1
emit("monitor.layout_changed")
check(rules["1"].gaps_out.top == 96 and rules["1"].gaps_out.left == 144, "odd transform swaps raw pixel dimensions before scaling")

local lifecycle = ws(90)
M.page(90, { cap = 1, floating = true })
local older = win("older", lifecycle, false, false, true)
local newer = win("newer", lifecycle, false, false, true)
M.page(lifecycle.id, { floating = false })
flush()
check(not older.floating and not newer.floating and older.workspace ~= newer.workspace, "switching back to tiled enforces cap")
local newcomer = win("newcomer", lifecycle, false, false, true)
check(newcomer.workspace ~= lifecycle, "opening past cap enforces it")
local arrival = win("arrival", later)
move(arrival, lifecycle); flush()
check(arrival.workspace ~= lifecycle, "moving onto tiled page enforces cap after move settles")
local external = ws(100, monitors[2])
local default_window = win("default-window", external, false, false, true)
check(default_window.floating, "new window on a monitor's floating default page floats")

local failed = ws(110)
win("rename-failure", failed)
reject_dispatch = "change_id"
check(not pcall(M.compact) and failed.id == 110 and page(110).cap == 2, "failed rename does not move page settings")
reject_dispatch = nil
M.compact(); flush()
check(failed.id ~= 110 and page(failed.id).cap == 2, "compaction guard recovers after dispatcher failure")

-- Preserve the actual emitted file for the JS model contract check.
local out = assert(io.open(output_path, "w")); out:write(read(M.FILE)); out:close()
check(not io.open(M.FILE .. ".tmp"), "atomic write leaves no temp file")

-- Reset holds weak objects while earlier targets can move focus. Simulate an
-- empty target expiring on the first focus change caused by overflow.
M.default("DP-4", { cap = 3, floating = false, gap = 8 })
local reset_page = ws(200)
M.page(200, { cap = 3, gap = 32, zen = true })
win("reset-a", reset_page); win("reset-b", reset_page); win("reset-c", reset_page)
local expired = ws(201)
local survivor = ws(202)
M.page(202, { gap = 28, zen = true })
flush()
M.default("DP-4", { cap = 1, gap = 8 })
on_focus = function()
    on_focus = nil
    remove(expired)
    for key in pairs(expired) do expired[key] = nil end
    setmetatable(expired, { __index = function(_, key)
        check(key == "id", "reset must check the weak workspace id before its monitor")
        return nil
    end })
end
M.reset("DP-4")
flush()
check(expired.id == nil, "reset regression expired an empty target during enforcement")
check(not page(survivor.id).own and not page(survivor.id).zen, "reset skips expired target and continues with remaining pages")

-- Plain brackets must remain window cycling, not duplicate gap actions.
local config = read(config_path)
for _, side in ipairs({ "bracketleft", "bracketright" }) do
    local prefix = 'hl.bind(mod .. " + ' .. side .. '",'
    local first = assert(config:find(prefix, 1, true), "cycle binding missing")
    check(not config:find(prefix, first + #prefix, true), "plain bracket must have only one binding")
    check(config:find('hl.bind(mod .. " + SHIFT + ' .. side .. '", function() page_layout.step_gap', 1, true), "gap binding needs Shift")
end
check(config:find('hl.dsp.layout("cycleprev")', 1, true) and config:find('hl.dsp.layout("cyclenext")', 1, true), "cycle actions remain installed")
check(config:find('hl.bind(mod .. " + CTRL + F", function() page_layout.toggle_window_floating() end)', 1, true), "manual float binding clears module ownership")
assert(os.execute("rm -r " .. dir))
print("page-layout: all tests passed")
