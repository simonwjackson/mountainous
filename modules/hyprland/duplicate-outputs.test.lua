local policy = dofile(arg[1])
local function output(name, overrides)
    local m = { name = name, description = "YMK EM160TP-A 0x00000001",
        width = 2880, height = 1800, refresh_rate = 60 }
    for k, v in pairs(overrides or {}) do m[k] = v end
    return m
end
local function expect(monitors, wanted)
    local got = policy.plan(monitors)
    for name, source in pairs(wanted) do assert(got[name] == source, name); got[name] = nil end
    assert(next(got) == nil)
end
expect({}, {})
expect({output("DP-3")}, {})
expect({output("DP-3"), output("DP-1"), output("eDP-1")}, { ["DP-3"] = "DP-1" })
expect({output("DP-1"), output("eDP-1"), output("DP-3")}, { ["DP-3"] = "DP-1" })
expect({output("DP-1"), output("DP-3"), output("DP-5")}, { ["DP-3"] = "DP-1", ["DP-5"] = "DP-1" })
-- Source unplug: promote the remaining connector, never mirror it to itself.
expect({output("DP-3"), output("eDP-1")}, {})
expect({output("DP-3"), output("DP-5")}, { ["DP-5"] = "DP-3" })
-- Same model is not sufficient if description or current mode differs.
for _, changed in ipairs({{description="another panel"}, {width=1920}, {height=1200}, {refresh_rate=120}, {description=""}}) do
    expect({output("DP-1"), output("DP-3", changed)}, {})
end
expect({output("eDP-1"), output("DP-1")}, {})
expect({output("DP-1", {description=""}), output("DP-3", {description=""})}, {})
expect({output("DP-1", {width=0}), output("DP-3", {width=0})}, {})
-- Timing noise below 0.01 Hz is not a different mode.
expect({output("DP-1"), output("DP-3", {refresh_rate=60.001})}, { ["DP-3"] = "DP-1" })
print("PASS duplicate-output policy: order, hot-plug, 3 copies, mode differences, eDP-1")
