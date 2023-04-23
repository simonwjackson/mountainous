local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
require("awful.autofocus")
local gears = require("gears")
local aria2_widget = require("aria2_status")
-- require("beautiful.xresources").apply_dpi()

-- {{{ Wibar
-- Create a textclock widget
local mytextclock = wibox.widget({
  font = "NotoSans Nerd Font Bold 10",
  widget = wibox.widget.textclock("%-I:%M")
})

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
  awful.button({}, 1, function(t) t:view_only() end)
)

local fifo_widget = wibox.container.margin(wibox.widget {
  id = "text",
  text = "󰋋",
  font = "20",
  visible = false,
  widget = wibox.widget.textbox
}, 15, 5, 5, 5) -- Function to update the widget

local function update_widget(widget)
  local fifo = io.open("/tmp/bluetooth_status.fifo", "r")
  local output = fifo:read("*l")

  fifo:close()

  if output == "1" then
    widget.visible = true
  else
    widget.visible = false
  end
end


-- Watch the FIFO and update the widget
awful.widget.watch("cat /tmp/bluetooth_status.fifo", 1, update_widget, fifo_widget)

awful.screen.connect_for_each_screen(function(s)
  -- Each screen has its own tag table.
  awful.tag({ "●", "●", "●" }, s, awful.layout.layouts[1])

  -- Create a promptbox for each screen
  -- s.mypromptbox = awful.widget.prompt()
  -- Create an imagebox widget which will contain an icon indicating which layout we're using.
  -- We need one layoutbox per screen.
  s.mylayoutbox = awful.widget.layoutbox(s)
  s.mylayoutbox:buttons(gears.table.join(
    awful.button({}, 1, function() awful.layout.inc(1) end),
    awful.button({}, 3, function() awful.layout.inc(-1) end),
    awful.button({}, 4, function() awful.layout.inc(1) end),
    awful.button({}, 5, function() awful.layout.inc(-1) end))
  )
  -- Create a taglist widget
  s.mytaglist = awful.widget.taglist {
    screen  = s,
    filter  = awful.widget.taglist.filter.all,
    buttons = taglist_buttons,
    -- layout          = {
    --   spacing = 4,
    --   layout  = wibox.layout.fixed.horizontal
    -- },
    -- widget_template = {
    --   {
    --     {
    --       {
    --         id     = 'text_role',
    --         widget = wibox.widget.textbox,
    --       },
    --       left   = 8,
    --       right  = 8,
    --       widget = wibox.container.margin,
    --     },
    --     id     = 'background_role',
    --     widget = wibox.container.background,
    --   },
    --   create_callback = function(self, t, index, objects)
    --     self:get_children_by_id('text_role')[1].markup = '<b>' .. t.index .. '</b>'
    --   end,
    --   update_callback = function(self, t, index, objects)
    --     self:get_children_by_id('text_role')[1].markup = '<b>' .. t.index .. '</b>'
    --   end,
    -- },
  }

  -- Create a tasklist widget
  -- s.mytasklist = awful.widget.tasklist {
  --   screen  = s,
  --   filter  = awful.widget.tasklist.filter.currenttags,
  --   buttons = tasklist_buttons,
  -- }
  --
  -- beautiful.tasklist_fg_focus = "#00ff00" -- Active (focused) text color
  -- beautiful.tasklist_bg_focus = "#ff0000" -- Active (focused) background color
  beautiful.taglist_fg_focus = "#FFFFFF"      -- Active (selected) text color
  beautiful.taglist_fg_urgent = "#FFFFFF99"   -- Active (selected) text color
  beautiful.taglist_fg_occupied = "#FFFFFF99" -- Active (selected) text color
  beautiful.taglist_fg_empty = "#FFFFFF99"    -- Active (selected) text color
  -- beautiful.taglist_bg_focus = "#00000000" -- Active (selected) background color

  -- Create the wibox
  s.mywibox = awful.wibar({
    height = 64,
    position = "top",
    screen = s,
    type = "dock",
    width = s.geometry.width - 80,
  })

  s.mywibox.bg = "#00000000" -- Replace with your desired background color

  -- Add widgets to the wibox
  s.mywibox:setup {
    layout = wibox.layout.align.horizontal,
    {
      -- Left widgets
      layout = wibox.layout.fixed.horizontal,
      s.mytaglist,
      s.mypromptbox,
    },

    -- s.mytasklist, -- Middle widget
    nil,
    {
      -- Right widgets
      layout = wibox.layout.fixed.horizontal,
      spacing = 10,
      -- wibox.widget.systray(),
      fifo_widget,
      aria2_widget.icon_widget,
      mytextclock,
    },
  }
end)
-- }}}
