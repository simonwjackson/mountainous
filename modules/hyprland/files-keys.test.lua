-- Super+E opens Files, Super+D is Show Desktop and Super+X flips light and
-- dark, each bound once. Super+Shift+D is no longer bound.
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
n, line = binds("D")
assert(n == 1, "Super+D bound " .. n .. " times")
assert(line:find('qs -c mountainous ipc call showDesktop toggle', 1, true), "Super+D is Show Desktop: " .. line)
n, line = binds("X")
assert(n == 1 and line:find("desktop-theme toggle", 1, true), "Super+X flips light and dark")
n = binds("SHIFT + D")
assert(n == 0, "Super+Shift+D is unbound")
print("files keys: Super+E runs hensou-files, Super+D toggles Show Desktop, Super+X flips light and dark")
