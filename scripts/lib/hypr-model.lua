-- A small model of Hyprland 0.56's Lua API, enough to run the real
-- hyprland.lua and session modules offline. Rules, workspaces, focus,
-- timers and events behave as the source does; rendering does not exist.
local Model = {}
Model.__index = Model

-- hl.config merges into what earlier calls set, as Hyprland does.
local function merge(into, from)
    for k, v in pairs(from) do
        if type(v) == "table" then
            if type(into[k]) ~= "table" then into[k] = {} end
            merge(into[k], v)
        else
            into[k] = v
        end
    end
end

local function node(model, path)
    return setmetatable({}, {
        __index = function(_, key) return node(model, path == "" and key or path .. "." .. key) end,
        __call = function(_, args, rules) return { kind = path, args = args, rules = rules } end,
    })
end

function Model.new()
    local m = setmetatable({ now = 0, seq = 0, handlers = {}, timers = {}, rules = {}, rule_by_name = {},
        binds = {}, launches = {}, notes = {}, dispatched = {}, ws = {}, windows = {},
        monitor_rules = {}, devices = {}, plugins = {} }, Model)
    -- The panel. Each monitor shows one page; m.active is the focused one.
    m.monitor = { name = "eDP-1", width = 2880, height = 1800, scale = 1.5 }
    m.monitors = { m.monitor }
    m:show(m:workspace(1))
    local hl = setmetatable({}, { __index = function() return function() end end })
    hl.dsp = node(m, "")
    hl.notification = { create = function(o) m.notes[#m.notes + 1] = o.text end }
    hl.on = function(name, fn)
        local sub = { fn = fn, active = true }
        function sub:remove() self.active = false end
        m.handlers[name] = m.handlers[name] or {}
        table.insert(m.handlers[name], sub)
        return sub
    end
    hl.timer = function(fn, o)
        local t = { fn = fn, due = m.now + o.timeout, every = o.type == "repeat" and o.timeout, on = true }
        function t:set_enabled(v) self.on = v end
        m.timers[#m.timers + 1] = t
        return t
    end
    hl.window_rule = function(spec)
        local rule = spec.name and m.rule_by_name[spec.name]
        if not rule then
            rule = { effects = {} }
            function rule:set_enabled(v) self.enabled = v end
            function rule:is_enabled() return self.enabled end
            m.rules[#m.rules + 1] = rule
            if spec.name then m.rule_by_name[spec.name] = rule end
        end
        rule.enabled = spec.enabled ~= false
        rule.class = spec.match and spec.match.class
        for k, v in pairs(spec) do
            if k ~= "name" and k ~= "enabled" and k ~= "match" then rule.effects[#rule.effects + 1] = { k, v } end
        end
        return rule
    end
    hl.config = function(t) m.config = m.config or {}; merge(m.config, t) end
    -- A plugin never loads here, so hl.plugin.<name> stays nil.
    hl.plugin = { load = function(path) m.plugins[#m.plugins + 1] = path end }
    hl.bind = function(keys, handler) m.binds[keys] = handler end
    hl.define_submap = function(_, _, fn) if fn then fn() end end
    hl.exec_cmd = function(cmd) m.launches[#m.launches + 1] = cmd end
    hl.dispatch = function(d) m:dispatch(d) end
    hl.get_windows = function()
        local out = {}
        for _, w in ipairs(m.windows) do out[#out + 1] = w end
        return out
    end
    hl.get_workspaces = function()
        local out = {}
        for _, ws in pairs(m.ws) do out[#out + 1] = ws end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end
    hl.get_active_workspace = function() return m.active end
    hl.get_active_window = function() return m.focus end
    hl.get_monitors = function() return { table.unpack(m.monitors) } end
    hl.monitor = function(rule) m.monitor_rules[rule.output] = rule end
    hl.device = function(rule) m.devices[rule.name] = rule end
    hl.is_key_down = function() return false end
    m.hl = hl
    return m
end

-- A new page opens on the focused monitor, as Hyprland's does.
function Model:workspace(key, monitor)
    for _, ws in pairs(self.ws) do
        if ws.name == tostring(key) then return ws end
    end
    local special = type(key) == "string" and key:match("^special:") ~= nil
    local id = special and -98 or tonumber(key)
    monitor = monitor or (self.active and self.active.monitor) or self.monitor
    local ws = { id = id, name = tostring(key), special = special, list = {}, windows = 0, monitor = monitor }
    function ws.get_windows(self_) return { table.unpack(self_.list) } end
    self.ws[ws] = ws
    return ws
end

-- Focus a page: its monitor shows it, and it becomes the active page.
function Model:show(ws)
    if not ws.special then ws.monitor.shown = ws end
    self.active = ws
end

-- A page is kept while it holds a window or a monitor shows it.
function Model:shown(ws)
    for _, mon in ipairs(self.monitors) do
        if mon.shown == ws then return true end
    end
    return ws == self.active
end

-- Attach a monitor. Hyprland gives it a new empty page with the lowest
-- free id (output/Monitor.cpp setupDefaultWS), and focus stays put.
function Model:add_monitor(name)
    local mon = { name = name, width = 2960, height = 1848, scale = 1.6 }
    self.monitors[#self.monitors + 1] = mon
    local used = {}
    for _, ws in pairs(self.ws) do used[ws.id] = true end
    local id = 1
    while used[id] do id = id + 1 end
    mon.shown = self:workspace(id, mon)
    return mon
end

-- Detach a monitor. Hyprland moves every page it had to the first
-- remaining monitor (CMonitor::onDisconnect) and then collects empties.
function Model:remove_monitor(name)
    for i, mon in ipairs(self.monitors) do
        if mon.name == name then
            table.remove(self.monitors, i)
            local backup = self.monitors[1]
            for _, ws in pairs(self.ws) do
                if ws.monitor == mon then ws.monitor = backup end
            end
            if self.active.monitor == backup or self.active.monitor == mon then
                self:show(backup.shown)
            end
            self:collect()
            return
        end
    end
end

-- Page names on one monitor, in id order.
function Model:pages(name)
    local out = {}
    for _, ws in pairs(self.ws) do
        if not ws.special and ws.monitor.name == name then out[#out + 1] = ws end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    for i, ws in ipairs(out) do out[i] = ws.name end
    return out
end

function Model:emit(name, ...)
    for _, sub in ipairs(self.handlers[name] or {}) do
        if sub.active then sub.fn(...) end
    end
end

-- The master layout on a 1920-wide page. The first tiled window is master;
-- the ratio sets its width and the side sets where it sits. Hyprland keeps
-- the side per page and the ratio on the master node, which for a page
-- comes to the same thing here.
function Model:layout(ws)
    local master = self.config and self.config.master or {}
    local ratio = ws.mfact or master.mfact or 0.5
    local side = ws.side or master.orientation or "left"
    local tiled = {}
    for _, w in ipairs(ws.list) do
        if w.floating then w.layout = nil else tiled[#tiled + 1] = w end
    end
    for i, w in ipairs(tiled) do
        w.layout = { name = "master", is_master = i == 1, perc_master = ratio, perc_size = 1 }
        if #tiled == 1 then
            w.at = { x = 0, y = 0 }
        elseif i == 1 then
            w.at = { x = side == "left" and 0 or math.floor(1920 * (1 - ratio)), y = 0 }
        else
            w.at = { x = side == "left" and math.floor(1920 * ratio) or 0, y = (i - 2) * 100 }
        end
    end
    ws.windows = #ws.list
end

function Model:collect()
    for _, ws in pairs(self.ws) do
        if ws.windows == 0 and not self:shown(ws) then
            self.ws[ws] = nil
            self:emit("workspace.removed", ws)
        end
    end
end

function Model:place(w, ws)
    if w.workspace then
        local old = w.workspace
        for i, other in ipairs(old.list) do
            if other == w then table.remove(old.list, i) break end
        end
        self:layout(old)
    end
    w.workspace = ws
    table.insert(ws.list, w)
    self:layout(ws)
end

local function rule_matches(pattern, class)
    if not pattern then return false end
    local exact = pattern:match("^%^(.*)%$$")
    if exact then return exact:gsub("\\(.)", "%1") == class end
    return pattern == class
end

-- Map a window as Hyprland does: rules choose the workspace, then
-- open_early, then the layout, then open.
function Model:map(class, title, pid)
    self.seq = self.seq + 1
    local w = { address = string.format("0x%x", self.seq), class = class, title = title, pid = pid or self.seq,
        mapped = true, floating = false, pinned = false, fullscreen = 0,
        at = { x = 0, y = 0 }, size = { x = 800, y = 600 }, monitor = self.active.monitor }
    local target = self.active
    for _, rule in ipairs(self.rules) do
        if rule.enabled and rule_matches(rule.class, class) then
            for _, e in ipairs(rule.effects) do
                if e[1] == "workspace" then target = self:workspace((e[2]:gsub(" silent$", "")))
                elseif e[1] == "float" then w.floating = e[2]
                elseif e[1] == "pin" then w.pinned = e[2]
                elseif e[1] == "move" then w.at = { x = e[2][1], y = e[2][2] } end
            end
        end
    end
    w.workspace = target
    w.first_workspace = target.name
    self:emit("window.open_early", w)
    w.workspace = nil
    self:place(w, target)
    self.windows[#self.windows + 1] = w
    self.focus = w
    self:emit("window.open", w)
    return w
end

function Model:close(w)
    for i, other in ipairs(self.windows) do
        if other == w then table.remove(self.windows, i) break end
    end
    for i, other in ipairs(w.workspace.list) do
        if other == w then table.remove(w.workspace.list, i) break end
    end
    self:layout(w.workspace)
    if self.focus == w then self.focus = nil end
    self:emit("window.destroy", w)
    self:collect()
end

function Model:find(selector)
    local address = selector and selector:match("^address:(.+)$")
    for _, w in ipairs(self.windows) do
        if w.address == address then return w end
    end
end

function Model:dispatch(d)
    if type(d) == "function" then return d() end
    self.dispatched[#self.dispatched + 1] = d.kind
    local a = d.args or {}
    if d.kind == "focus" then
        if a.window then
            self.focus = self:find(a.window)
            -- Focusing a window shows its page.
            if self.focus and not self.focus.workspace.special then
                self:show(self.focus.workspace)
                self:collect()
            end
        end
        if a.workspace then self:show(self:workspace(a.workspace)) self:collect() end
    elseif d.kind == "window.move" and a.workspace then
        local w = a.window and self:find(a.window) or self.focus
        if w then self:place(w, self:workspace(a.workspace)) self:collect() end
    elseif d.kind == "window.swap" then
        local x, y = self:find(a.window), self:find(a.target)
        local wx, wy = x.workspace, y.workspace
        local ix, iy
        for i, w in ipairs(wx.list) do if w == x then ix = i end end
        for i, w in ipairs(wy.list) do if w == y then iy = i end end
        wx.list[ix], wy.list[iy] = y, x
        x.workspace, y.workspace = wy, wx
        self:layout(wx)
        self:layout(wy)
    elseif d.kind == "layout" then
        -- Layout messages act on the focused window's page.
        local ws = self.focus and self.focus.workspace
        if ws then
            local default = self.config and self.config.master and self.config.master.orientation or "left"
            local ratio = d.args:match("^mfact exact ([%d%.]+)$")
            local side = d.args:match("^orientation(%a+)$")
            if ratio then ws.mfact = tonumber(ratio)
            elseif d.args == "orientationcycle left right" then
                ws.side = (ws.side or default) == "left" and "right" or "left"
            elseif side then ws.side = side end
            self:layout(ws)
        end
    elseif d.kind == "workspace.change_id" then
        local ws = self:workspace(a.workspace)
        ws.id, ws.name = a.id, tostring(a.id)
    end
end

-- What Hyprland drops on a config reload before it runs the file again.
function Model:reset_config()
    self.handlers, self.timers, self.rules, self.rule_by_name, self.binds = {}, {}, {}, {}, {}
end

function Model:press(keys)
    self:dispatch(self.binds[keys])
end

function Model:advance(ms)
    local stop = self.now + ms
    while true do
        local next_t
        for _, t in ipairs(self.timers) do
            if t.on and t.due <= stop and (not next_t or t.due < next_t.due) then next_t = t end
        end
        if not next_t then break end
        self.now = next_t.due
        if next_t.every then next_t.due = next_t.due + next_t.every else next_t.on = false end
        next_t.fn()
        if self.after then self:after() end
    end
    self.now = stop
end

-- Workspace name of every window, keyed by title.
function Model:where()
    local out = {}
    for _, w in ipairs(self.windows) do out[w.title] = w.workspace.name end
    return out
end

return Model
