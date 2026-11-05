-- Floating windows fit the usable screen.
--
-- Hyprland 0.56.2 places a new or newly floated window inside the work area
-- but never shrinks it (DefaultFloatingAlgorithm.cpp: fitBoxInWorkArea and
-- newTarget move the box, they do not touch its size). A window whose size is
-- the monitor's, or a tiled window floated at its tiled size, is therefore
-- taller than the area above the taskbar: Hyprland pushes it up until its
-- bottom meets the taskbar, and its top and title bar go off the screen by
-- the taskbar's height plus the bar's. Measured on Myoko: a floated tiled
-- terminal came out 960x1200 on a 1920x1200 output with a 38 px reserved
-- bottom, 58 px above the top edge.
--
-- This module shrinks such a window to the usable area, keeps it centred
-- where it was, and keeps its title bar on the screen. A window that already
-- fits is never touched.

local M = {}

-- Pure. box = { x, y, w, h } in global logical pixels, without the title bar.
-- monitor = { x, y, width, height, scale, reserved = { top, right, bottom, left } }
-- with width/height in physical pixels, as hl.get_monitors() reports them.
-- bar = the title bar's height above box.y, in logical pixels.
-- Returns the box to apply, or nil when the window already fits.
function M.plan(box, monitor, bar)
    bar = bar or 0
    local r = monitor.reserved or {}
    local ux = monitor.x + (r.left or 0)
    local uy = monitor.y + (r.top or 0)
    local uw = math.floor(monitor.width / monitor.scale + 0.5) - (r.left or 0) - (r.right or 0)
    local uh = math.floor(monitor.height / monitor.scale + 0.5) - (r.top or 0) - (r.bottom or 0)
    local fits = box.x >= ux and box.y - bar >= uy
        and box.x + box.w <= ux + uw and box.y + box.h <= uy + uh
    if fits then return nil end
    local w = math.min(box.w, uw)
    local h = math.min(box.h, uh - bar)
    -- Keep the window's centre, then pull it inside the usable area.
    local x = math.floor(box.x + box.w / 2 - w / 2 + 0.5)
    local y = math.floor(box.y + box.h / 2 - h / 2 + 0.5)
    x = math.max(ux, math.min(x, ux + uw - w))
    y = math.max(uy + bar, math.min(y, uy + uh - h))
    return { x = x, y = y, w = w, h = h }
end

local function find(address)
    for _, w in ipairs(hl.get_windows()) do
        if w.address == address then return w end
    end
    return nil
end

-- Pure. Whether a window, as hl.get_windows() reports it, should be fitted.
-- `fullscreen` is a mode number there, and 0 (not fullscreen) is true in Lua.
function M.eligible(w)
    return w ~= nil and w.floating == true and (w.fullscreen or 0) == 0 and w.monitor ~= nil
end

local function fit_now(address, bar_height)
    local w = find(address)
    if not M.eligible(w) then return end
    local m = w.monitor
    local box = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    local target = M.plan(box, {
        x = m.x, y = m.y, width = m.width, height = m.height, scale = m.scale,
        reserved = m.reserved,
    }, bar_height())
    if not target then return end
    local selector = "address:" .. address
    hl.dispatch(hl.dsp.window.resize({ x = target.w, y = target.h, window = selector }))
    hl.dispatch(hl.dsp.window.move({ x = target.x, y = target.y, window = selector }))
end

-- opts.bar_height: function returning the current title bar height (0 when
-- there is none). Returns fit_soon(address), for callers that float a window.
function M.attach(opts)
    local bar_height = (opts and opts.bar_height) or function() return 0 end
    local timers = {}
    -- Clients apply their own initial size after the map (Ghostty's GTK
    -- geometry, for one), so measure a moment later.
    local function fit_soon(address)
        if not address or timers[address] then return end
        timers[address] = hl.timer(function()
            timers[address] = nil
            pcall(fit_now, address, bar_height)
        end, { timeout = 150, type = "oneshot" })
    end
    hl.on("window.open", function(w)
        if w and w.address then fit_soon(w.address) end
    end)
    M.fit_soon = fit_soon
    return fit_soon
end

return M
