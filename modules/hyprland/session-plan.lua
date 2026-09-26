-- Pure planning for session restore. No hl.* calls, so tests load it
-- with a plain Lua 5.5 interpreter. See docs/decisions/session-restore.md.
local M = {}

M.EXCLUDED = { ["org.quickshell"] = true, ["xembedsniproxy"] = true }

-- The process a window belongs to is not always a good way to start it
-- again. These classes relaunch through their installed launcher.
M.LAUNCHER = { ["dev.zed.Zed"] = "zeditor" }

function M.quote(s)
    if s:match("^[%w%%%+,%-%./:=@_]+$") then return s end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- /proc/<pid>/cmdline is NUL separated. Chromium rewrites its own to one
-- space-joined field, which the second branch undoes.
function M.split_cmdline(raw)
    local argv = {}
    for arg in (raw or ""):gmatch("[^%z]+") do argv[#argv + 1] = arg end
    if #argv == 1 and argv[1]:find(" ", 1, true) then
        local parts = {}
        for arg in argv[1]:gmatch("%S+") do parts[#parts + 1] = arg end
        argv = parts
    end
    return argv
end

-- exists(name) reports whether a launcher of that name is installed.
function M.launch_command(class, argv, exists)
    if #argv == 0 then return nil end
    if class:match("^chrome%-") then
        for i = 2, #argv do
            local url = argv[i]:match("^%-%-app=(.+)$")
            local host = url and url:match("^https?://([^/:?#]+)")
            if host and class == "chrome-" .. host .. "__-Default" then
                return "web-app " .. M.quote(url)
            end
        end
    end
    if M.LAUNCHER[class] then return M.LAUNCHER[class] end
    local program = argv[1]
    if class == "chromium-browser" and program:find("chromium-unwrapped-", 1, true) then
        program = "chromium"
    elseif program:match("^/nix/store/") then
        local base = program:match("([^/]+)$")
        if exists(base) then program = base end
    end
    local out = { M.quote(program) }
    for i = 2, #argv do out[#out + 1] = M.quote(argv[i]) end
    return table.concat(out, " ")
end

-- windows: { class, title, pid, special_name|nil, ws_id, floating, pinned,
--            fullscreen, at = {x, y}, size = {x, y}, command }
-- Returns the snapshot, or nil when there is nothing worth keeping.
function M.capture(windows, capacity, default_capacity)
    local ids, count = {}, {}
    for _, w in ipairs(windows) do
        if not w.special_name then
            ids[w.ws_id] = true
            if not w.floating then count[w.ws_id] = (count[w.ws_id] or 0) + 1 end
        end
    end
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    table.sort(sorted)
    local page_of, pages = {}, {}
    for page, id in ipairs(sorted) do
        page_of[id] = page
        -- A page that holds N tiled windows has room for at least N, even
        -- when the in-memory capacity was lost to a config reload.
        pages[page] = { capacity = math.max(capacity[id] or default_capacity, count[id] or 0) }
    end

    local out, spawned = {}, {}
    for _, w in ipairs(windows) do
        out[#out + 1] = {
            class = w.class, title = w.title or "",
            page = w.special_name and nil or page_of[w.ws_id],
            special = w.special_name,
            floating = w.floating or false, pinned = w.pinned or false,
            fullscreen = w.fullscreen or 0,
            at = { w.at[1], w.at[2] }, size = { w.size[1], w.size[2] },
            command = w.command, pid = w.pid,
        }
    end
    table.sort(out, function(a, b)
        if (a.page or math.huge) ~= (b.page or math.huge) then return (a.page or math.huge) < (b.page or math.huge) end
        if (a.special or "") ~= (b.special or "") then return (a.special or "") < (b.special or "") end
        if a.floating ~= b.floating then return not a.floating end
        if a.at[1] ~= b.at[1] then return a.at[1] < b.at[1] end
        if a.at[2] ~= b.at[2] then return a.at[2] < b.at[2] end
        if a.class ~= b.class then return a.class < b.class end
        return a.title < b.title
    end)
    for _, w in ipairs(out) do
        -- One launch per process and class. A single-instance app opens
        -- its other windows itself; a Chromium app window can share a
        -- process with a browser window and still needs its own launch.
        local key = tostring(w.pid) .. "\0" .. w.class
        w.spawn = w.command ~= nil and not spawned[key]
        spawned[key] = true
        w.pid = nil
    end
    if #out == 0 then return nil end
    return { version = 1, pages = pages, windows = out }
end

-- Deterministic, so two captures of the same desktop are equal strings.
function M.serialize(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        return math.type(v) == "integer" and tostring(v) or string.format("%.17g", v)
    end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" then error("cannot serialize " .. t) end
    local inner = indent .. "  "
    local parts = {}
    if #v > 0 then
        for _, item in ipairs(v) do parts[#parts + 1] = inner .. M.serialize(item, inner) end
    else
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k
                or "[" .. M.serialize(k) .. "]"
            parts[#parts + 1] = inner .. key .. " = " .. M.serialize(v[k], inner)
        end
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
end

function M.decode(text)
    local chunk = load(text, "=session", "t", {})
    if not chunk then return nil end
    local ok, value = pcall(chunk)
    if ok and type(value) == "table" and value.version == 1 and type(value.windows) == "table" then
        return value
    end
    return nil
end

function M.regex_escape(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?{}|\\]", "\\%0"))
end

function M.target(w)
    return w.special or tostring(w.page)
end

-- Saved windows grouped by class, in saved order.
function M.slots(snapshot)
    local by_class, classes = {}, {}
    for index, w in ipairs(snapshot.windows) do
        if not by_class[w.class] then
            by_class[w.class] = {}
            classes[#classes + 1] = w.class
        end
        local list = by_class[w.class]
        list[#list + 1] = index
    end
    return by_class, classes
end

-- Pair saved windows of one class with the live windows restored for it.
-- Exact title first, then arrival order. Titles change after launch, so
-- they only correct the order; they are never required.
function M.pair(snapshot, slot_indices, lives)
    local pairs_out, used_slot, used_live = {}, {}, {}
    for _, si in ipairs(slot_indices) do
        for li, live in ipairs(lives) do
            if not used_live[li] and live.title == snapshot.windows[si].title then
                pairs_out[si] = live
                used_slot[si], used_live[li] = true, true
                break
            end
        end
    end
    local li = 1
    for _, si in ipairs(slot_indices) do
        if not used_slot[si] then
            while li <= #lives and used_live[li] do li = li + 1 end
            if li > #lives then break end
            pairs_out[si] = lives[li]
            used_live[li] = true
        end
    end
    return pairs_out
end

-- Swaps that turn `live` (addresses in layout order) into `want`.
function M.order_swaps(want, live)
    local current, swaps = {}, {}
    for i, a in ipairs(live) do current[i] = a end
    for i, a in ipairs(want) do
        if current[i] ~= a then
            for j = i + 1, #current do
                if current[j] == a then
                    swaps[#swaps + 1] = { current[i], a }
                    current[i], current[j] = current[j], current[i]
                    break
                end
            end
        end
    end
    return swaps
end

return M
