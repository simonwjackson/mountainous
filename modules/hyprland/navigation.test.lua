-- Exercise the shipped navigation callbacks with real page-layout helpers.
local config_path, module_path = arg[1], arg[2]
local file = assert(io.open(config_path))
local source = file:read("*a"); file:close()
local navigation = assert(source:match('(local function find_window_by.-)\n%-%- Kamoi Meta%+Tab'))
local page_layout = dofile(module_path)
local bindings, actions = {}, {}
local active, current, spaces, directional_target
local function dispatcher(args) return args end
hl = {
    get_active_window = function() return active end,
    get_active_workspace = function() return current end,
    get_workspaces = function() return spaces end,
    bind = function(key, callback) bindings[key] = callback end,
    dsp = { focus = dispatcher, window = { move = dispatcher } },
    dispatch = function(action)
        actions[#actions + 1] = action
        if action.direction and directional_target then active = directional_target end
        return { ok = true }
    end,
}
assert(load('local mod, page_layout = ...\n' .. navigation))("SUPER", page_layout)
local function workspace(id, monitor, windows)
    return { id = id, monitor = monitor, windows = #windows, get_windows = function() return windows end }
end
local monitor = { name = "eDP-1" }
local function window(address, x, y, floating, pinned)
    return { address = address, at = { x = x, y = y }, floating = floating, pinned = pinned }
end
local first = window("first", 0, 0)
local right = window("right", 100, 0)
local bottom = window("bottom", 0, 100)
local corner = window("corner", 100, 100)
local targets = { first, right, bottom, corner,
    window("floater", -100, -100, true), window("pin", 200, 200, false, true) }
local previous = workspace(1, monitor, targets)
current = workspace(3, monitor, { window("current", 0, 0) })
local following = workspace(5, { name = monitor.name }, targets)
spaces = { workspace(-1, monitor, targets), previous,
    workspace(2, { name = "DP-1" }, targets), current, workspace(4, monitor, {}), following,
    workspace(6, monitor, targets) }
local function press(key)
    actions = {}
    bindings["SUPER + " .. key]()
end
for key, address in pairs({ H = "right", left = "right", K = "bottom", up = "bottom",
    L = "first", right = "first", J = "first", down = "first" }) do
    active, directional_target = current:get_windows()[1], nil
    press(key)
    assert(#actions == 2 and actions[2].window == "address:" .. address, key .. " walks to a tiled window on the nearest occupied page of this monitor")
end
active, directional_target = current:get_windows()[1], first
press("L")
assert(#actions == 1, "native directional focus wins, including across monitors")
active, directional_target = nil, nil
press("L")
assert(#actions == 1 and actions[1].window == "address:first", "empty active page still walks")
following.get_windows = function() return { window("only-floater", 0, 0, true) } end
press("L")
assert(actions[1].workspace == 5, "a page without tiled windows is focused by workspace")
spaces = { current }
press("H")
assert(#actions == 0, "strip boundary does not wrap")
current.special = true
press("L")
assert(#actions == 0, "special overlay does not walk pages")
current = nil
press("L")
assert(#actions == 0, "missing active workspace is safe")
print("navigation: page walk, monitor boundaries, pinned/floating windows and native focus pass")
