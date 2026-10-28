-- One workspace destination per physical display. Mirroring, not disabling,
-- keeps the picture whichever connector a hub actually wires to its panel.
local M = {}

-- Pure policy: the input includes active outputs and their mirrors. A stable
-- connector order makes hot-plug order irrelevant. Never change eDP-1.
function M.plan(monitors)
    local sorted, sources, mirrors = {}, {}, {}
    for _, m in ipairs(monitors) do
        if m.name ~= "eDP-1" and m.description and m.description ~= ""
            and m.width > 0 and m.height > 0 and m.refresh_rate > 0 then
            sorted[#sorted + 1] = m
        end
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    for _, m in ipairs(sorted) do
        local source
        for _, s in ipairs(sources) do
            if m.description == s.description and m.width == s.width
                and m.height == s.height and math.abs(m.refresh_rate - s.refresh_rate) < 0.01 then
                source = s
                break
            end
        end
        if source then mirrors[m.name] = source.name
        else sources[#sources + 1] = m end
    end
    return mirrors
end

function M.attach()
    local managed = {}
    local timer
    local function reconcile()
        local monitors, by_name = {}, {}
        local function add(m)
            if not by_name[m.name] then
                by_name[m.name] = m
                monitors[#monitors + 1] = m
            end
        end
        for _, m in ipairs(hl.get_monitors()) do
            add(m)
            -- get_monitors excludes mirrors; their source exposes them.
            for _, mirror in ipairs(m.mirrors) do add(mirror) end
        end
        local wanted = M.plan(monitors)
        local function rule(name, mirror)
            local m = by_name[name]
            return { output = name, mirror = mirror,
                mode = string.format("%dx%d@%.3f", m.width, m.height, m.refresh_rate),
                position = string.format("%dx%d", m.x, m.y),
                scale = tostring(m.scale), transform = m.transform }
        end
        -- Clear our previous mirror rules before moving a source. Unplugging
        -- the source promotes its mirror in Hyprland; remove the stale rule
        -- too so a later reload cannot strand it. Leave manual mirrors alone.
        for name, previous in pairs(managed) do
            if not wanted[name] then
                previous.rule.mirror = ""
                hl.monitor(previous.rule)
                managed[name] = nil
            end
        end
        for name, source in pairs(wanted) do
            if not managed[name] or managed[name].source ~= source then
                local spec = rule(name, source)
                hl.monitor(spec)
                managed[name] = { source = source, rule = spec }
            end
        end
    end
    local function schedule()
        if timer then timer:set_enabled(false) end
        -- Monitor events fire inside layout mutation. Reconcile after it,
        -- coalescing hot-plug bursts and our own mirror/layout events.
        timer = hl.timer(reconcile, { timeout = 150, type = "oneshot" })
    end
    hl.on("monitor.added", schedule)
    hl.on("monitor.removed", schedule)
    hl.on("monitor.layout_changed", schedule)
    schedule()
end

return M
