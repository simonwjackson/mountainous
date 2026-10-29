-- Kamoi's page settings and strip. The bar consumes snapshot(), through
-- $XDG_RUNTIME_DIR/mountainous-page-layout.json; commands use the same state.
local json = require("dkjson")
local M = { FALLBACK = { cap = 1, floating = false, gap = 8 } }
local state_dir = (os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/mountainous"
local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
M.FILE = runtime .. "/mountainous-page-layout.json"
M.DEFAULTS_FILE = state_dir .. "/page-layout-defaults.json"
-- Only provenance, not settings: a reload must not mistake our floaters for
-- hand-floated windows. Addresses are pruned against the live desktop at load.
local OWNED_FILE = runtime .. "/mountainous-page-layout-floated.json"
local pages, defaults, owned, pending = {}, {}, {}, {}
local rules, rule_values = {}, {}
local compacting, enforcing, held, attached = false, false, false, false

local function dispatch(action)
    local result = hl.dispatch(action)
    assert(result and result.ok, result and result.error or "Page layout: dispatch failed")
end
local function object(t) return setmetatable(t or {}, { __jsontype = "object" }) end
local function read_json(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    local value = json.decode(text)
    return type(value) == "table" and value or nil
end
local function write_json(path, value)
    local f, err = io.open(path .. ".tmp", "w")
    assert(f, "Page layout: cannot write " .. path .. ": " .. tostring(err))
    local ok, why = f:write(json.encode(value), "\n")
    local closed, close_err = f:close()
    assert(ok and closed, tostring(why or close_err))
    assert(os.rename(path .. ".tmp", path))
end
local function gap(n)
    assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "gap must be finite")
    return math.max(0, math.min(48, math.floor(n / 4 + 0.5) * 4))
end
local function values(v, zen)
    assert(type(v) == "table", "settings must be a table")
    local out = {}
    for k, n in pairs(v) do
        if k == "cap" then
            assert(type(n) == "number" and n % 1 == 0 and n >= 1 and n <= 3, "cap must be 1..3")
        elseif k == "gap" then n = gap(n)
        elseif k == "floating" or (zen and k == "zen") then
            assert(type(n) == "boolean", k .. " must be boolean")
        else error("unknown setting: " .. tostring(k)) end
        out[k] = n
    end
    return out
end
local function copy(v) return { cap = v.cap, floating = v.floating, gap = v.gap } end
local function monitor_key(m)
    return m.description and m.description ~= "" and m.description or m.name
end
local function default_of(m)
    return m and defaults[monitor_key(m)] or M.FALLBACK
end
local function initial(m) return copy(default_of(m) or M.FALLBACK) end
local function find_monitor(name)
    for _, m in ipairs(hl.get_monitors()) do if m.name == name then return m end end
    error("no connected monitor: " .. tostring(name))
end
local function workspace(id)
    if id == "active" then
        -- get_active_workspace can be a special overlay. The control targets
        -- the focused monitor's ordinary page even while an overlay is up.
        for _, m in ipairs(hl.get_monitors()) do
            if m.focused then
                local ws = m.active_workspace
                assert(ws and ws.id > 0, "no active page")
                return ws
            end
        end
        error("no focused monitor")
    end
    assert(type(id) == "number" and id > 0 and id % 1 == 0, "page must be a positive id or active")
    for _, ws in ipairs(hl.get_workspaces()) do if ws.id == id then return ws end end
    error("no page: " .. id)
end
local function ensure(ws)
    if not pages[ws.id] then
        local p = initial(ws.monitor)
        p.zen = false
        if pending[ws.id] then p.cap, pending[ws.id] = pending[ws.id], nil end
        pages[ws.id] = p
    end
    return pages[ws.id]
end
local function disable_rule(id)
    if rules[id] then rules[id]:set_enabled(false) end
    -- There is no remove method. Retain the disabled handle so reusing an
    -- id re-enables and replaces the same rule instead of leaking one per
    -- page creation/compaction cycle.
    rule_values[id] = nil
end
local function apply_gap(ws)
    local p, m = ensure(ws), ws.monitor
    local g = p.gap
    if p.zen and m then
        -- LuaMonitor exposes untransformed pixel dimensions. Monitor.cpp
        -- swaps them for odd transforms, then divides by scale for logical
        -- size. Keep Kamoi's shares in portrait and at fractional scales.
        local width, height = m.width, m.height
        if (m.transform or 0) % 2 == 1 then width, height = height, width end
        local side = math.floor(width / m.scale * 0.12)
        local vert = math.floor(height / m.scale * 0.05)
        g = { top = vert, right = side, bottom = vert, left = side }
    end
    local encoded = json.encode(g)
    if rule_values[ws.id] ~= encoded then
        -- workspace_rule replaces/merges an enabled rule with the same exact
        -- selector. Do not disable it first: that would grow a rule per edit.
        if rules[ws.id] then rules[ws.id]:set_enabled(true) end
        rules[ws.id] = hl.workspace_rule({ workspace = tostring(ws.id), gaps_out = g })
        rule_values[ws.id] = encoded
    end
end

function M.snapshot()
    local out = { version = 1, fallback = copy(M.FALLBACK), defaults = object(), pages = object() }
    for _, m in ipairs(hl.get_monitors()) do out.defaults[m.name] = initial(m) end
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 then
            local p, d = ensure(ws), initial(ws.monitor)
            local v = copy(p)
            v.monitor, v.zen = ws.monitor and ws.monitor.name or "", p.zen
            v.own = p.cap ~= d.cap or p.floating ~= d.floating or p.gap ~= d.gap
            out.pages[tostring(ws.id)] = v
        end
    end
    return out
end
local function publish()
    write_json(M.FILE, M.snapshot())
    write_json(OWNED_FILE, object(owned))
end
local function tiled_windows(ws)
    local out = {}
    for _, w in ipairs(ws:get_windows()) do
        -- Floating windows sit outside the tiled page, so Kamoi's capacity
        -- does not count them. Pinned windows must stay floating too.
        if not w.floating and not w.pinned then out[#out + 1] = w end
    end
    return out
end
local function arrange(ws)
    local p = ensure(ws)
    for _, w in ipairs(ws:get_windows()) do
        local selector = "address:" .. w.address
        if p.floating then
            if not w.floating and not w.pinned then
                dispatch(hl.dsp.window.float({ action = "on", window = selector }))
                owned[w.address] = ws.id
            elseif owned[w.address] then owned[w.address] = ws.id end
        elseif owned[w.address] then
            if w.floating and not w.pinned then
                dispatch(hl.dsp.window.float({ action = "off", window = selector }))
            end
            owned[w.address] = nil
        end
    end
end

-- The first id past the end of the strip. Every page counts, empty or not.
-- With a second monitor attached, that monitor always shows a page, and it
-- may be empty. An id past only occupied pages could be that page, and the
-- overflow window would land on the other screen.
local function end_of_strip()
    local maxid = 0
    for _, ws in ipairs(hl.get_workspaces()) do maxid = math.max(maxid, ws.id) end
    return maxid + 1
end

-- Capacity is a CAP, not a split ratio. The shapes fall out of master:
-- one fills the page, two give columns, three a master and two stacked.
-- No mfact is set here; that is Meta+G.
-- Move overflow newest first so the master end keeps the windows already
-- there. Each window gets a fresh page at the strip's end, not ws.id + 1:
-- id+1 may already be full, and opening is not raised by a move. Compaction
-- then pulls the page beside its neighbours: the end is only where it lands.
function M.enforce(ws)
    if not ws or ws.id <= 0 or enforcing or held then return end
    local p = ensure(ws)
    if p.floating then return end
    local wins = tiled_windows(ws)
    local over = #wins - p.cap
    if over <= 0 then return end
    enforcing = true
    local ok, err = pcall(function()
        local target = end_of_strip()
        for i = #wins, #wins - over + 1, -1 do
            dispatch(hl.dsp.focus({ window = "address:" .. wins[i].address }))
            dispatch(hl.dsp.window.move({ workspace = target }))
            target = target + 1
        end
    end)
    enforcing = false
    assert(ok, err)
    M.compact()
end

-- Keep the strip numbered 1..N with no holes. Pages are strip positions,
-- not names; left alone ids only climb (testing reached 21..23 in a session).
-- Empty pages still exist: each monitor can show one until you leave it.
-- Renaming an occupied page onto either empty id would collide.
-- Renaming in ascending order cannot collide. Let t[i] be the i-th positive
-- id no empty page holds. occ is sorted and holds no empty ids, so
-- occ[i] >= t[i]. At each rename, earlier pages hold t[j] < t[i] and later
-- pages hold occ[j] > occ[i] >= t[i]. The target is free.
function M.compact()
    -- Dispatch is synchronous. Never renumber under session restore or a
    -- move that is still placing overflow windows.
    if compacting or held or enforcing then return end
    compacting = true
    local ok, err = pcall(function()
        local occ, reserved = {}, {}
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id > 0 then
                ensure(ws)
                if ws.windows > 0 then occ[#occ + 1] = ws.id else reserved[ws.id] = true end
            end
        end
        table.sort(occ)
        local target = 0
        for _, id in ipairs(occ) do
            repeat target = target + 1 until not reserved[target]
            if id ~= target then
                dispatch(hl.dsp.workspace.change_id({ workspace = id, id = target }))
                pages[target], pages[id] = pages[id], nil
                for address, page in pairs(owned) do if page == id then owned[address] = target end end
                disable_rule(id)
                disable_rule(target)
            end
        end
    end)
    compacting = false
    assert(ok, err)
    M.refresh()
end
function M.hold(on)
    held = on
    -- Missing restore windows must not leave capacity overrides for unrelated
    -- pages created later with the same ids.
    if not on then pending = {} end
end

function M.page(id, settings)
    local change, ws = values(settings, true), workspace(id)
    local p = ensure(ws)
    for k, v in pairs(change) do p[k] = v end
    arrange(ws)
    apply_gap(ws)
    M.enforce(ws)
    publish()
end
function M.page_default(id, field)
    assert(field == "cap" or field == "floating" or field == "gap" or field == "all", "invalid default field")
    local ws = workspace(id)
    local d = initial(ws.monitor)
    M.page(ws.id, field == "all" and d or { [field] = d[field] })
end
function M.default(connector, settings)
    local change, mon = values(settings, false), find_monitor(connector)
    -- Capture pages before changing the default. Existing pages never inherit
    -- a later edit, even if they had no explicit user override.
    M.snapshot()
    local d = initial(mon)
    for k, v in pairs(change) do d[k] = v end
    defaults[monitor_key(mon)] = d
    write_json(M.DEFAULTS_FILE, object(defaults))
    publish()
end
function M.reset(connector)
    find_monitor(connector)
    local targets = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 and ws.monitor and ws.monitor.name == connector then targets[#targets + 1] = ws end
    end
    -- A reset can enforce capacity and renumber other targets. Keep workspace
    -- objects, not a list of ids that becomes stale after the first edit.
    for _, ws in ipairs(targets) do
        local d = initial(ws.monitor)
        d.zen = false
        M.page(ws.id, d)
    end
    publish()
end
function M.step_gap(id, delta)
    assert(type(delta) == "number" and delta == delta and math.abs(delta) < math.huge, "delta must be finite")
    local ws = workspace(id)
    M.page(ws.id, { gap = ensure(ws).gap + delta })
end
function M.toggle_floating(id)
    local ws = workspace(id)
    M.page(ws.id, { floating = not ensure(ws).floating })
end
function M.toggle_zen(id)
    local ws = workspace(id or "active")
    M.page(ws.id, { zen = not ensure(ws).zen })
end

-- Session restore reads and writes capacity[id]. This view shares the page
-- store, not a second capacity table. Writes for not-yet-created pages wait
-- until creation, when the monitor's other defaults become known.
M.capacity = setmetatable({}, {
    __index = function(_, id)
        if pages[id] then return pages[id].cap end
        for _, ws in ipairs(hl.get_workspaces()) do if ws.id == id then return ensure(ws).cap end end
        return pending[id] or M.FALLBACK.cap
    end,
    __newindex = function(_, id, n)
        assert(type(n) == "number" and n >= 1 and n % 1 == 0, "invalid restored capacity")
        n = math.min(3, n)
        if pages[id] then
            pages[id].cap = n
            publish()
        else pending[id] = n end
    end,
})

function M.refresh()
    if compacting then return end
    local live = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 then live[ws.id] = true; ensure(ws); apply_gap(ws) end
    end
    for id in pairs(pages) do
        if not live[id] then pages[id] = nil; disable_rule(id) end
    end
    local addresses = {}
    for _, w in ipairs(hl.get_windows()) do addresses[w.address] = true end
    for address in pairs(owned) do if not addresses[address] then owned[address] = nil end end
    publish()
end

-- Closing the last window should leave the page, not strand you on it.
-- Hyprland destroys an empty workspace only when you walk away. Measured:
-- after closing everything known=[3], occupied=[]; visiting 7 leaves [7];
-- leaving 7 leaves [1]. Stepping away lets Hyprland collect the dead page.
-- Only the same monitor qualifies: closing a window on one screen must not
-- pull focus and the pointer onto the other screen's empty page.
local function leave_if_empty()
    local here = hl.get_active_workspace()
    if not here or here.id <= 0 or here.windows > 0 then return end
    local best
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 and ws.id ~= here.id and ws.windows > 0 and ws.monitor and here.monitor
            and ws.monitor.name == here.monitor.name then
            local d = math.abs(ws.id - here.id)
            if not best or d < math.abs(best - here.id) or (d == math.abs(best - here.id) and ws.id < best) then best = ws.id end
        end
    end
    -- No target means the last window anywhere. Empty is a real state.
    if best then dispatch(hl.dsp.focus({ workspace = best })) end
end

function M.attach()
    if attached then return M end
    attached = true
    local stored = read_json(M.DEFAULTS_FILE) or {}
    for key, v in pairs(stored) do
        local ok, d = pcall(values, v, false)
        if ok and d.cap and d.gap and d.floating ~= nil then defaults[key] = d end
    end
    local previous = read_json(M.FILE)
    local provenance = read_json(OWNED_FILE) or {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 then
            local saved = previous and previous.version == 1 and type(previous.pages) == "table" and previous.pages[tostring(ws.id)]
            if type(saved) == "table" and saved.monitor == (ws.monitor and ws.monitor.name or "") then
                local ok, p = pcall(values, { cap = saved.cap, floating = saved.floating, gap = saved.gap, zen = saved.zen }, true)
                if ok then pages[ws.id] = p end
            end
            if not pages[ws.id] then
                -- A config reload must not split an existing tiled page just
                -- because its old in-memory capacity was lost.
                ensure(ws).cap = math.min(3, math.max(ensure(ws).cap, #tiled_windows(ws)))
            end
            for _, w in ipairs(ws:get_windows()) do
                if provenance[w.address] == ws.id and w.floating and not w.pinned then owned[w.address] = ws.id end
            end
            arrange(ws)
        end
    end
    local function on_window(w, ws)
        ws = ws or (w and w.workspace)
        if not ws or ws.id <= 0 then return end
        arrange(ws)
        M.enforce(ws)
        M.refresh()
    end
    hl.on("window.open", on_window)
    local move_timers = {}
    hl.on("window.move_to_workspace", function(w)
        if not w or not w.address then return end
        local address = w.address
        -- Window.cpp emits this midway through moveToWorkspace, before all
        -- layout/monitor state is settled. Float/enforce on the next tick,
        -- using the current workspace (compaction may already have run).
        if move_timers[address] then return end
        move_timers[address] = hl.timer(function()
            move_timers[address] = nil
            for _, current in ipairs(hl.get_windows()) do
                if current.address == address then on_window(current); break end
            end
        end, { timeout = 1, type = "oneshot" })
    end)
    hl.on("window.destroy", function(w)
        if w and w.address then owned[w.address] = nil end
        leave_if_empty()
        M.refresh()
    end)
    -- Do not leave on workspace.active: it kicks an intentional swipe off an
    -- empty page and causes re-entrant CUnifiedWorkspaceSwipeGesture::end().
    hl.on("workspace.created", M.refresh)
    hl.on("workspace.removed", M.compact)
    hl.on("workspace.move_to_monitor", M.refresh)
    for _, event in ipairs({ "monitor.added", "monitor.removed", "monitor.layout_changed", "hyprland.start" }) do
        hl.on(event, M.refresh)
    end
    -- Creation cannot leave holes. Never compact there: it disrupts gesture
    -- completion. Removal alone compacts and republishes renumbered settings.
    M.refresh()
    return M
end
return M
