-- Save the desktop and reopen it at the next login, inside the compositor.
-- hyprland.lua attaches this module when modules/session-restore.nix
-- installs it. See docs/decisions/session-restore.md.
local plan = require("session-plan")

local M = {}

-- Saving: capture every tick, and write only when two captures in a row
-- agree. Shutdown closes windows one by one; that never holds still long
-- enough to overwrite the last good snapshot.
local TICK_MS = 10000
-- Hyprland publishes its environment to systemd and D-Bus when it starts.
-- Launch after that, so apps find their portals.
local START_DELAY_MS = 2000
-- Restore ends this long after the last saved window opens, so titles can
-- settle before they order a page, or at the limit. Zed can wait for SSH
-- before it opens a window.
local SETTLE_MS = 5000
local LIMIT_MS = 300000
-- Moves must land before the layout order of a page can be read back.
local ORDER_DELAY_MS = 300

local HOME = os.getenv("HOME") or ""
-- modules/session-restore.nix creates this directory 0700: the snapshot
-- holds launch commands, and those can carry secrets.
local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/mountainous/session"
M.FILE = STATE_DIR .. "/snapshot.lua"
-- Per boot. Tells a reloaded config that a restore was cut short.
M.MARKER = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mountainous-session-restore"

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

local function write_atomic(path, text)
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "wb")
    if not f then return nil, err end
    f:write(text)
    f:close()
    return os.rename(tmp, path)
end

local BIN_DIRS = { "/run/current-system/sw/bin", "/etc/profiles/per-user/" .. (os.getenv("USER") or "") .. "/bin" }
function M.installed(name)
    for _, dir in ipairs(BIN_DIRS) do
        local f = io.open(dir .. "/" .. name, "rb")
        if f then f:close() return true end
    end
    return false
end

function M.read_cmdline(pid)
    return read("/proc/" .. pid .. "/cmdline")
end

local function notify(text)
    pcall(hl.notification.create, { text = "Session restore: " .. text, timeout = 8000 })
end

local function workspace_key(ws)
    if ws == nil then return nil end
    return ws.special and ws.name or tostring(ws.id)
end

function M.attach(strip)
    local state = { commands = {}, written = read(M.FILE), candidate = nil, restoring = false }
    state.quiet_until = tonumber(read(M.MARKER) or "") or 0
    local R = nil

    local function live_windows()
        local out = {}
        for _, w in ipairs(hl.get_windows()) do
            local ws = w.workspace
            if w.mapped and ws and (w.class or "") ~= "" and not plan.EXCLUDED[w.class] then
                -- Only tiled windows have a layout; it names the master and
                -- carries the page's split.
                local layout = (not w.floating) and w.layout or nil
                out[#out + 1] = {
                    master = layout and layout.is_master or false,
                    ratio = layout and layout.perc_master or nil,
                    address = w.address, class = w.class, title = w.title, pid = w.pid,
                    special_name = ws.special and ws.name or nil, ws_id = ws.id,
                    floating = w.floating, pinned = w.pinned, fullscreen = w.fullscreen,
                    at = { w.at.x, w.at.y }, size = { w.size.x, w.size.y },
                }
            end
        end
        return out
    end

    local function command_for(w)
        local cached = state.commands[w.address]
        if cached and cached.pid == w.pid then return cached.command end
        local argv = plan.split_cmdline(M.read_cmdline(w.pid))
        local command = plan.launch_command(w.class, argv, M.installed)
        state.commands[w.address] = { pid = w.pid, command = command }
        return command
    end

    local function capture()
        local wins, seen = live_windows(), {}
        for _, w in ipairs(wins) do
            w.command = command_for(w)
            seen[w.address] = true
        end
        for address in pairs(state.commands) do
            if not seen[address] then state.commands[address] = nil end
        end
        local snap = plan.capture(wins, strip.capacity, strip.default_capacity)
        return snap and ("return " .. plan.serialize(snap) .. "\n")
    end

    local function save(text)
        local ok, err = write_atomic(M.FILE, text)
        if ok then
            state.written, state.candidate = text, nil
        elseif not state.warned then
            state.warned = true
            notify("cannot save " .. M.FILE .. ": " .. tostring(err))
        end
    end

    local function tick()
        if state.restoring or os.time() < state.quiet_until then return end
        local text = capture()
        -- An empty desktop never replaces a saved one.
        if text == nil or text == state.written then
            state.candidate = nil
        elseif text == state.candidate then
            save(text)
        else
            state.candidate = text
        end
    end

    -- Ends a restore on every path, including an error, so the strip is
    -- never left with compaction suspended.
    local function release()
        if R and R.sub then pcall(function() R.sub:remove() end) end
        if R then
            for _, list in pairs(R.rules) do
                for _, rule in ipairs(list) do pcall(function() rule:set_enabled(false) end) end
            end
        end
        R = nil
        state.restoring = false
        state.quiet_until = 0
        os.remove(M.MARKER)
        strip.hold(false)
        strip.compact()
    end

    local function guarded(fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then
                pcall(release)
                notify(tostring(err))
            end
        end
    end

    local function order_pages()
        for page = 1, #R.snap.pages do
            local want = {}
            for si, w in ipairs(R.snap.windows) do
                if w.page == page and not w.floating and R.address_of[si] then
                    want[#want + 1] = R.address_of[si]
                end
            end
            local here = {}
            for _, w in ipairs(hl.get_windows()) do
                if w.workspace and w.workspace.id == page and not w.floating and R.tracked[w.address] then
                    here[#here + 1] = w
                end
            end
            table.sort(here, function(a, b)
                if a.at.x ~= b.at.x then return a.at.x < b.at.x end
                return a.at.y < b.at.y
            end)
            local live = {}
            for i, w in ipairs(here) do live[i] = w.address end
            if #want == #live then
                for _, s in ipairs(plan.order_swaps(want, live)) do
                    hl.dispatch(hl.dsp.window.swap({ window = "address:" .. s[1], target = "address:" .. s[2] }))
                end
            end
        end
        release()
    end

    -- Split and master side are set on the focused page, so this focuses
    -- one window on each page that needs a change, then returns to the page
    -- you were on. It runs before ordering: which window is master decides
    -- where each window sits, and the order is read from those positions.
    local function apply_layouts()
        local active = hl.get_active_workspace()
        local back = active and not active.special and active.id or nil
        local hopped = false
        for page, p in ipairs(R.snap.pages) do
            local messages = plan.layout_messages(p, strip.layout_defaults)
            local anchor = nil
            for si, w in ipairs(R.snap.windows) do
                if w.page == page and not w.floating and R.address_of[si] then
                    anchor = R.address_of[si]
                    break
                end
            end
            if #messages > 0 and anchor then
                hl.dispatch(hl.dsp.focus({ window = "address:" .. anchor }))
                for _, message in ipairs(messages) do hl.dispatch(hl.dsp.layout(message)) end
                hopped = true
            end
        end
        if hopped and back then hl.dispatch(hl.dsp.focus({ workspace = back })) end
        hl.timer(guarded(order_pages), { timeout = ORDER_DELAY_MS, type = "oneshot" })
    end

    local function finish()
        if R == nil or R.finishing then return end
        R.finishing = true
        if R.sub then pcall(function() R.sub:remove() end) end
        R.sub = nil
        for _, list in pairs(R.rules) do
            for _, rule in ipairs(list) do rule:set_enabled(false) end
        end
        local current = {}
        for _, w in ipairs(hl.get_windows()) do current[w.address] = w end
        local missing = {}
        for class, slots in pairs(R.by_class) do
            local lives = {}
            for _, address in ipairs(R.lives[class] or {}) do
                if current[address] then lives[#lives + 1] = { address = address, title = current[address].title } end
            end
            local paired = plan.pair(R.snap, slots, lives)
            for _, si in ipairs(slots) do
                local live = paired[si]
                if live == nil then
                    missing[#missing + 1] = class
                else
                    R.address_of[si] = live.address
                    local want = plan.target(R.snap.windows[si])
                    if workspace_key(current[live.address].workspace) ~= want then
                        hl.dispatch(hl.dsp.window.move({ workspace = want, follow = false, window = "address:" .. live.address }))
                    end
                end
            end
        end
        if #missing > 0 then
            table.sort(missing)
            notify(#missing .. " window(s) did not reopen: " .. table.concat(missing, ", "))
        end
        hl.timer(guarded(apply_layouts), { timeout = ORDER_DELAY_MS, type = "oneshot" })
    end

    local function on_open(w)
        if R == nil or R.finishing or R.tracked[w.address] then return end
        local slots = R.by_class[w.class]
        local k = slots and R.next[w.class]
        if not k or k > #slots then return end
        R.rules[w.class][k]:set_enabled(false)
        if R.rules[w.class][k + 1] then R.rules[w.class][k + 1]:set_enabled(true) end
        R.next[w.class] = k + 1
        R.tracked[w.address] = true
        R.lives[w.class] = R.lives[w.class] or {}
        table.insert(R.lives[w.class], w.address)
        R.remaining = R.remaining - 1
        if R.remaining == 0 then
            hl.timer(guarded(finish), { timeout = SETTLE_MS, type = "oneshot" })
        end
    end

    local function begin()
        if state.started then return end
        state.started = true
        local snap = plan.decode(read(M.FILE) or "")
        -- A populated desktop is left alone.
        if snap == nil or #live_windows() > 0 then return end
        state.restoring = true
        write_atomic(M.MARKER, tostring(os.time() + LIMIT_MS // 1000 + 60))
        strip.hold(true)
        for page, p in ipairs(snap.pages) do strip.capacity[page] = p.capacity end

        local by_class, classes = plan.slots(snap)
        R = { snap = snap, by_class = by_class, next = {}, rules = {}, lives = {},
              tracked = {}, address_of = {}, remaining = #snap.windows }
        -- One rule per saved window. Only the next slot of each class is
        -- enabled, so a single-instance app's second window, which no
        -- launch carries, still reaches its own page.
        for _, class in ipairs(classes) do
            R.next[class], R.rules[class] = 1, {}
            for k, si in ipairs(by_class[class]) do
                local w = snap.windows[si]
                local spec = {
                    name = "session-restore:" .. class .. ":" .. k,
                    enabled = k == 1,
                    match = { class = "^" .. plan.regex_escape(class) .. "$" },
                    workspace = plan.target(w) .. " silent",
                    float = w.floating, pin = w.pinned,
                }
                if w.floating then
                    spec.move, spec.size = { w.at[1], w.at[2] }, { w.size[1], w.size[2] }
                end
                if w.fullscreen == 2 then spec.fullscreen = true elseif w.fullscreen == 1 then spec.maximize = true end
                R.rules[class][k] = hl.window_rule(spec)
            end
        end
        R.sub = hl.on("window.open_early", guarded(on_open))
        for _, w in ipairs(snap.windows) do
            if w.spawn and w.command then hl.exec_cmd(w.command) end
        end
        hl.timer(guarded(finish), { timeout = LIMIT_MS, type = "oneshot" })
    end

    hl.on("hyprland.start", function()
        hl.timer(guarded(begin), { timeout = START_DELAY_MS, type = "oneshot" })
    end)
    -- The exit dispatcher emits this; a reboot's SIGTERM does not.
    hl.on("hyprland.shutdown", function()
        if state.restoring then return end
        local text = capture()
        if text and text ~= state.written then save(text) end
    end)
    hl.timer(tick, { timeout = TICK_MS, type = "repeat" })

    M._test = { tick = tick, begin = begin, state = state }
    return M
end

return M
