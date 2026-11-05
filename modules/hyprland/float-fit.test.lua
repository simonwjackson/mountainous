-- Floating windows fit the usable screen (float-fit.lua).
-- Run: lua float-fit.test.lua float-fit.lua
local M = dofile(arg[1])

local function eq(got, want, what)
    if got == nil and want == nil then return end
    assert(got and want, what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    for _, k in ipairs({ "x", "y", "w", "h" }) do
        assert(got[k] == want[k], string.format("%s: %s = %s, want %s", what, k, tostring(got[k]), tostring(want[k])))
    end
end

-- Myoko's upper output: 2880x1800 at 1.5 = 1920x1200 logical, placed at
-- y = -1200, with the 38 px taskbar reserved at the bottom.
local upper = { x = 0, y = -1200, width = 2880, height = 1800, scale = 1.5,
    reserved = { top = 0, right = 0, bottom = 38, left = 0 } }

-- The measured bug: a floated tiled terminal, 960x1200, pushed up to sit on
-- the taskbar, 38 px above the top edge, plus a 20 px title bar.
eq(M.plan({ x = 480, y = -1238, w = 960, h = 1200 }, upper, 20),
    { x = 480, y = -1180, w = 960, h = 1142 }, "full-height float shrinks under its title bar")

-- The title bar stays on screen; the bottom stays above the taskbar.
local fixed = M.plan({ x = 480, y = -1238, w = 960, h = 1200 }, upper, 24)
assert(fixed.y - 24 >= upper.y, "Memphis caption on screen")
assert(fixed.y + fixed.h <= upper.y + 1200 - 38, "bottom above the taskbar")

-- A window that fits is left alone.
eq(M.plan({ x = 560, y = -919, w = 800, h = 600 }, upper, 20), nil, "an 800x600 floater fits")

-- Wider than the screen: width shrinks too, centre kept, then clamped.
eq(M.plan({ x = -100, y = -900, w = 2200, h = 400 }, upper, 20),
    { x = 0, y = -900, w = 1920, h = 400 }, "too wide")

-- Only the title bar overflows: move down, keep the size.
eq(M.plan({ x = 100, y = -1190, w = 800, h = 600 }, upper, 20),
    { x = 100, y = -1180, w = 800, h = 600 }, "title bar above the top edge moves down")

-- A reserved top bar (Platinum's) counts too.
local platinum = { x = 0, y = 0, width = 2880, height = 1800, scale = 1.5,
    reserved = { top = 30, right = 0, bottom = 0, left = 0 } }
eq(M.plan({ x = 0, y = 0, w = 1920, h = 1200 }, platinum, 20),
    { x = 0, y = 50, w = 1920, h = 1150 }, "under the Platinum menu bar")

-- No title bar (another theme): the window only needs the usable area.
eq(M.plan({ x = 0, y = -1200, w = 1920, h = 1200 }, upper, 0),
    { x = 0, y = -1200, w = 1920, h = 1162 }, "no title bar")

-- Eligibility uses Hyprland's window fields: fullscreen is a mode number.
assert(M.eligible({ floating = true, fullscreen = 0, monitor = {} }), "a floating, non-fullscreen window is fitted")
assert(not M.eligible({ floating = true, fullscreen = 1, monitor = {} }), "a fullscreen window is left alone")
assert(not M.eligible({ floating = false, fullscreen = 0, monitor = {} }), "a tiled window is left alone")

print("float-fit: floats shrink to the usable area, keep their title bar on screen, and fitting floats are untouched")
