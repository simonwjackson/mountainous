-- Super+E opens Files and Super+Shift+D is Show Desktop, each bound once,
-- and neither chord is taken by another bind.
-- Run: lua files-keys.test.lua hyprland.lua
local file = assert(io.open(arg[1], "r"))
local source = file:read("*a")
file:close()
local function binds(chord)
    local n, line = 0, nil
    for l in source:gmatch("[^\n]+") do
        if l:match('^%s*hl%.bind%(mod %.%. " %+ ' .. chord:gsub("%+", "%%+") .. '"') then n = n + 1; line = l end
    end
    return n, line
end
local n, line = binds("E")
assert(n == 1, "Super+E bound " .. n .. " times")
assert(line:find('hl.dsp.exec_cmd("hensou-files")', 1, true), "Super+E runs hensou-files: " .. line)
n, line = binds("SHIFT + D")
assert(n == 1, "Super+Shift+D bound " .. n .. " times")
assert(line:find('qs -c mountainous ipc call showDesktop toggle', 1, true), "Super+Shift+D is Show Desktop: " .. line)
n, line = binds("D")
assert(n == 1 and line:find("desktop-theme toggle", 1, true), "Super+D stays the theme toggle")
print("files keys: Super+E runs hensou-files, Super+Shift+D toggles Show Desktop, Super+D unchanged")
