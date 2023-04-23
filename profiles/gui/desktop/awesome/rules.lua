-- local wibox = require("wibox")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")
local gears = require("gears")

local clientbuttons = gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end)
)

-- local youruniqueclass_wibox = wibox({ visible = false, ontop = true, type = "normal" })

-- local overlay_wibox = wibox({
--   visible = false,
--   ontop = true,
--   -- below = true,
--   above = true,
--   type = "normal",
--   bg = "#000000AA"
-- })

-- awful.placement.maximize(overlay_wibox)

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
  -- All clients will match this rule.
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus = awful.client.focus.filter,
      raise = true,
      -- keys = nil,
      buttons = clientbuttons,
      screen = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  },

  -- Floating clients.
  {
    rule_any = {
      instance = {
        "DTA",   -- Firefox addon DownThemAll.
        "copyq", -- Includes session name in class.
        "pinentry",
      },
      class = {
        "Arandr",
        "Blueman-manager",
        "Gpick",
        "Kruler",
        "MessageWin",  -- kalarm.
        "Sxiv",
        "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
        "Wpa_gui",
        "veromix",
        "xtightvncviewer" },
      -- Note that the name property shown in xprop might be set slightly after creation of the client
      -- and the name shown there might not match defined rules here.
      name = {
        "Event Tester", -- xev.
      },
      role = {
        "AlarmWindow",   -- Thunderbird's calendar.
        "ConfigManager", -- Thunderbird's about:config.
        "pop-up",        -- e.g. Google Chrome's (detached) Developer Tools.
      }
    },
    properties = { floating = true }
  },

  -- Add titlebars to normal clients and dialogs
  {
    rule_any = { type = { "normal", "dialog" }
    },
    properties = { titlebars_enabled = true }
  },

  {
    rule_any = {
      class = { "floater" },
    },
    -- instance = "floater",
    -- You can customize the size and position of the kitty window by changing the values below.
    properties = {
      floating = true,
      above = true,
      ontop = true,
      width = awful.screen.focused().geometry.width * 0.5,
      height = awful.screen.focused().geometry.height * 0.5,
      x = awful.screen.focused().geometry.width * 0.25,
      y = awful.screen.focused().geometry.height * 0.25
    }
  }


  -- Set Firefox to always map on the tag named "2" on screen 1.
  -- { rule = { class = "Firefox" },
  --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- client.connect_signal("focus", function(c)
--   if c.class ~= "YourUniqueClass" then
--     overlay_wibox.visible = false
--     youruniqueclass_wibox.visible = false
--   else
--     overlay_wibox.visible = true
--     youruniqueclass_wibox.visible = true
--
--     -- Lower all other clients
--     -- for _, other_c in ipairs(c.screen.clients) do
--     --   if other_c.class == "floater" then
--     --     other_c:lower()
--     --   end
--     -- end
--   end
-- end)
-- client.connect_signal("unmanage", function(c)
--   if c.class == "YourUniqueClass" then
--     overlay_wibox.visible = false
--     youruniqueclass_wibox.visible = false
--   end
-- end)
--
-- client.connect_signal("unmanage", function(c)
--   if c.class == "YourUniqueClass" then
--     overlay_wibox.visible = false
--     youruniqueclass_wibox.visible = false
--   end
-- end)
