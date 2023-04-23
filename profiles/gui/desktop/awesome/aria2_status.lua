local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local aria2_widget = {}

aria2_widget.icons = {
  downloading = "", -- Nerdfont icon for downloading
  paused = ""     -- Nerdfont icon for paused
}

aria2_widget.icon_widget = wibox.widget.textbox()
-- aria2_widget.icon_widget.font = "FiraCode Nerd Font 12"

-- Function to update the aria2 widget icon
function aria2_widget:update_icon(status)
  if status == "downloading" then
    self.icon_widget.text = self.icons.downloading
  elseif status == "paused" then
    self.icon_widget.text = self.icons.paused
  else
    self.icon_widget.text = "X"
  end
end

-- Function to toggle aria2 pause/resume
function aria2_widget:toggle_aria2()
  awful.spawn.easy_async_with_shell(
    "curl -s -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"aria2.tellActive\",\"params\":[\"token:MY_TOKEN_HERE\"]}' http://localhost:6800/jsonrpc",
    function(stdout)
      local active_downloads = gears.string.split(stdout, "\n")
      local command = #active_downloads > 0 and "aria2.pauseAll" or "aria2.unpauseAll"

      awful.spawn.easy_async_with_shell(
        "curl -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"" ..
        command .. "\",\"params\":[\"token:mysecret\"]}' http://localhost:6800/jsonrpc", function()
        end
      )
    end)
end

-- Attach the click event
aria2_widget.icon_widget:connect_signal("button::press", function() aria2_widget:toggle_aria2() end)

return aria2_widget
