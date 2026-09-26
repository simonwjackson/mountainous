-- A small model of Hyprland 0.56's Lua API, enough to run the real
-- hyprland.lua and session modules offline. Rules, workspaces, focus,
-- timers and events behave as the source does; rendering does not exist.
local Model = {}
Model.__index = Model

local function node(model, path)
    return setmetatable({}, {
        __index = function(_, key) return node(model, path == "" and key or path .. "." .. key) end,
        __call = function(_, args, rules) return { kind = path, args = args, rules = rules } end,
    })
end

function Model.new()
    local m = setmetatable({ now = 0, seq = 0, handlers = {}, timers = {}, rules = {}, rule_by_name = {},
        binds = {}, launches = {}, notes = {}, dispatched = {}, ws = {}, windows = {} }, Model)
    m.monitor = { width = 2880, height = 1800, scale = 1.5 }
    m.active = m:workspace(1)
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
    hl.get_monitors = function() return { m.monitor } end
    hl.is_key_down = function() return false end
    m.hl = hl
    return m
end

function Model:workspace(key)
    for _, ws in pairs(self.ws) do
        if ws.name == tostring(key) then return ws end
    end
    local special = type(key) == "string" and key:match("^special:") ~= nil
    local id = special and -98 or tonumber(key)
    local ws = { id = id, name = tostring(key), special = special, list = {}, windows = 0 }
    function ws.get_windows(self_) return { table.unpack(self_.list) } end
    self.ws[ws] = ws
    return ws
end

function Model:emit(name, ...)
    for _, sub in ipairs(self.handlers[name] or {}) do
        if sub.active then sub.fn(...) end
    end
end

function Model:layout(ws)
    local tiled = 0
    for _, w in ipairs(ws.list) do
        if not w.floating then
            tiled = tiled + 1
            w.at = tiled == 1 and { x = 0, y = 0 } or { x = 960, y = (tiled - 2) * 100 }
        end
    end
    ws.windows = #ws.list
end

function Model:collect()
    for _, ws in pairs(self.ws) do
        if ws.windows == 0 and ws ~= self.active then
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
        at = { x = 0, y = 0 }, size = { x = 800, y = 600 }, monitor = self.monitor }
    local target = self.active
    for _, rule in ipairs(self.rules) do
        if rule.enabled and rule_matches(rule.class, class) then
            for _, e in ipairs(rule.effects) do
                if e[1] == "workspace" then target = self:workspace(e[2]:gsub(" silent$", ""))
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
        if a.window then self.focus = self:find(a.window) end
        if a.workspace then self.active = self:workspace(a.workspace) self:collect() end
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
