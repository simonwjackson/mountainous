-- The Moonlight client's monitor, as Hyprland sees it. modules/sunshine.nix
-- installs this file next to hyprland.lua, which attaches it.
--
-- modules/second-screen.py decides the rule when a client connects and
-- writes it to a runtime file. This module only applies that file. It does
-- so on demand (`hyprctl eval 'require("second-screen").apply()'`) and at
-- every config load, because a reload drops rules made by eval: without the
-- second, saving hyprland.lua mid-stream would throw the client's monitor to
-- Hyprland's default position, beside the panel instead of under it.
local M = {}

M.OUTPUT = "SUNSHINE"
-- modules/second-screen.py writes the same path; keep the two in step.
M.STATE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mountainous-second-screen.lua"

-- Sunshine's virtual touchscreen and pen report positions from 0 to 1
-- across the streamed monitor (src/platform/virtualhid_input.cpp). Hyprland
-- maps an unbound touch device to a monitor of its own choosing, so a touch
-- on the tablet could land on the laptop panel. Names are libvirtualhid's
-- profile names as Hyprland spells devices: lower case, spaces as dashes.
M.DEVICES = { "libvirtualhid-touchscreen", "libvirtualhid-pen-tablet" }

function M.apply()
    local ok, rule = pcall(dofile, M.STATE)
    if not ok or type(rule) ~= "table" then return false end
    hl.monitor(rule)
    return true
end

function M.attach()
    for _, name in ipairs(M.DEVICES) do
        hl.device({ name = name, output = M.OUTPUT })
    end
    M.apply()
end

return M
