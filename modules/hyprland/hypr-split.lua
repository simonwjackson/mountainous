-- Kamoi Meta+G: toggle the focused page between an even and a golden
-- split. hypr-split (modules/hyprland.nix) runs this with `hyprctl eval`.
--
-- The ratio is read from the page itself. A single flag file for the whole
-- desktop made the key do nothing visible on the next page, which was
-- still even while the flag said golden.
local EVEN, GOLDEN = 0.5, 0.61803

local w = hl.get_active_window()
local layout = w and w.layout
if layout == nil or layout.perc_master == nil then return end
local golden = math.abs(layout.perc_master - GOLDEN) < 0.01
hl.dispatch(hl.dsp.layout(string.format("mfact exact %.5f", golden and EVEN or GOLDEN)))
