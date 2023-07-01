-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

local awful = require("awful")

require("awful.autofocus")
require("errors")
require("layouts")
require("themes")
require("bars")
require("rules")
require("signals")

require("beautiful").font = "NotoSans Nerd Font Bold 10"

local inner_padding_file = os.getenv("HOME") .. "/.cache/awesome/inner_gap"
local outer_margin_file = os.getenv("HOME") .. "/.cache/awesome/outer_gap"
local last_tag_file = os.getenv("HOME") .. "/.cache/awesome/last_tag"

local naughty = require("naughty")

-- Add this code block somewhere in the file, e.g., at the end
awesome.connect_signal("open_prs_updated", function()
	local file_path = os.getenv("HOME") .. "/.cache/github/open-prs"
	local f = io.open(file_path, "r")

	if f ~= nil then
		local open_prs_count = f:read("*all")
		f:close()

		if open_prs_count ~= nil and open_prs_count ~= "" then
			-- Perform any action with the open_prs_count value, for example:
			-- Display a notification with the number of open PRs
			naughty.notify({ title = "Open PRs", text = "You have " .. open_prs_count .. " PRs to review" })
		else
			naughty.notify({ title = "Error", text = "Could not read the open PRs count" })
		end
	else
		naughty.notify({ title = "Error", text = "Could not open " .. file_path })
	end
end)

-- Restore the previously focused tag after a restart
awful.spawn.easy_async_with_shell("cat " .. last_tag_file, function(stdout)
	local tag_index = tonumber(stdout) or 4

	if tag_index and tag_index > 0 then
		local current_screen = awful.screen.focused()
		local target_tag = current_screen.tags[tag_index]

		if target_tag then
			target_tag:view_only()
		end
	end
end)

function CustomReload()
	local file, err = io.open(last_tag_file, "w")

	if file then
		file:write(tostring(awful.screen.focused().selected_tag.index))
		file:close()
	else
		print("Error: Unable to save tag_file. " .. err)
	end

	awesome.restart()
end

local beautiful = require("beautiful")

local macNotch = 35
Outer_Gap = 0

-- Change useless_gap incrementally
function Inc_Inner_Padding(inc)
	local current_gap = beautiful.useless_gap

	Set_Inner_Padding(current_gap + inc)
end

function Set_Inner_Padding(num)
	beautiful.useless_gap = num

	for s in screen do
		for _, t in ipairs(s.tags) do
			t.gap = beautiful.useless_gap
		end
	end

	Set_Outer_Margin(Outer_Gap)
	Save_Inner_Padding()
end

-- Save and load gap settings
function Save_Inner_Padding()
	local gap_file, err = io.open(inner_padding_file, "w")

	if gap_file then
		gap_file:write(tostring(beautiful.useless_gap))
		gap_file:close()
	else
		print("Error: Unable to save inner_gap. " .. err)
	end
end

function Load_Inner_Gap()
	local gap_file = io.open(inner_padding_file, "r")

	if gap_file then
		local saved_gap = tonumber(gap_file:read("*all"))

		if saved_gap then
			beautiful.useless_gap = saved_gap
		end

		gap_file:close()
	end
end

--
--
--
--
--
--
-- Change_Outer_Gap
function Inc_Outer_Margin(inc)
	Set_Outer_Margin(Outer_Gap + inc)
end

function Set_Outer_Margin(outer_margin)
	local inner_padding = beautiful.useless_gap or 0

	for s in screen do
		s.padding = {
			top = outer_margin - inner_padding * 2,
			right = outer_margin - inner_padding * 2,
			bottom = outer_margin - inner_padding * 2,
			left = outer_margin - inner_padding * 2,
		}
	end

	Save_Outer_Margin(outer_margin)
end

function Save_Outer_Margin(outer_margin)
	Outer_Gap = outer_margin
	local gap_file, err = io.open(outer_margin_file, "w")

	if gap_file then
		gap_file:write(tostring(outer_margin))
		gap_file:close()
	else
		print("Error: Unable to save outer_gap. " .. err)
	end
end

function Load_Outer_Margin()
	local gap_file, err = io.open(outer_margin_file, "r")
	local inner_padding = tonumber(beautiful.useless_gap)

	if gap_file then
		local saved_gap = tonumber(gap_file:read("*all"))

		if saved_gap then
			Outer_Gap = saved_gap

			for s in screen do
				s.padding = {
					top = Outer_Gap - inner_padding * 2,
					right = Outer_Gap - inner_padding * 2,
					bottom = Outer_Gap - inner_padding * 2,
					left = Outer_Gap - inner_padding * 2,
				}
			end
		end

		gap_file:close()
	else
		print("Error: Unable to load outer_gap. " .. err)
	end
end

--
--
-- Load saved gap settings
Load_Inner_Gap()
Load_Outer_Margin()

-- local wibox = require("wibox")
--
-- -- Create the dmenu-like widget
-- local function create_dmenu_widget(s)
--   local dmenu_widget = wibox.widget {
--     layout = wibox.layout.fixed.horizontal,
--     spacing = beautiful.taglist_spacing,
--     {
--       id = "prompt",
--       widget = wibox.widget.textbox,
--     },
--   }
--
--   -- Create the dmenu-like prompt
--   local dmenu_prompt = awful.widget.prompt {
--     prompt = "",
--     textbox = dmenu_widget.prompt,
--     exe_callback = function(command)
--       awful.spawn(command)
--       dmenu_widget.visible = false
--     end,
--     done_callback = function()
--       dmenu_widget.visible = false
--     end,
--   }
--
--   -- Create a wibox containing the dmenu-like widget
--   local dmenu_wibox = awful.wibar({
--     screen = s,
--     position = "top",
--     height = 20,
--     width = s.geometry.width,
--     visible = false,
--     ontop = true,
--     bg = beautiful.bg_normal,
--     fg = beautiful.fg_normal,
--     widget = dmenu_widget,
--   })
--
--   return {
--     widget = dmenu_widget,
--     prompt = dmenu_prompt,
--     wibox = dmenu_wibox,
--   }
-- end
--
-- -- Create dmenu-like widget and prompt for each screen
-- local dmenu_widgets = {}
-- awful.screen.connect_for_each_screen(function(s)
--   dmenu_widgets[s] = create_dmenu_widget(s)
-- end)
--
--
-- -- Custom signal for toggling dmenu-like widget
-- awesome.connect_signal("toggle_dmenu", function()
--   local screen = awful.screen.focused()
--   local dmenu_widget = dmenu_widgets[screen]
--   dmenu_widget.widget.visible = not dmenu_widget.widget.visible
--   if dmenu_widget.widget.visible then
--     dmenu_widget.prompt:run()
--   end
-- end)

local wibox = require("wibox")
local gears = require("gears")

local hello_wibox = wibox({
	visible = false,
	ontop = true,
	type = "normal",
	shape = gears.shape.rounded_rect,
	width = 300,
	height = 100,
})

local input_field = wibox.widget.textbox()
input_field.forced_width = 200
input_field.forced_height = 30

hello_wibox:setup({
	layout = wibox.layout.align.vertical,
	{
		{
			markup = "<b>Hello World</b>",
			align = "center",
			valign = "center",
			widget = input_field,
		},
		margins = 10,
		widget = wibox.container.margin,
	},
	bg = "#ff0000",
	widget = wibox.container.background,
})

awful.placement.centered(hello_wibox)

local function echo_test()
	awful.prompt.run({
		prompt = "<b>Echo: </b>",
		text = "default command",
		bg_cursor = "#ff0000",
		textbox = input_field,
		exe_callback = function(input)
			hello_wibox.visible = false
			if not input or #input == 0 then
				return
			end
			naughty.notify({ text = "The input was: " .. input })
		end,
	})
end

awesome.connect_signal("toggle_prompt", function() end)

awesome.connect_signal("toggle_hello", function()
	hello_wibox.visible = not hello_wibox.visible
	echo_test()
end)

function Rotate_Screens(direction)
	local current_screen = awful.screen.focused()
	local initial_scren = current_screen

	while true do
		awful.screen.focus_relative(direction)
		local next_screen = awful.screen.focused()
		if next_screen == initial_scren then
			return
		end

		local current_screen_tag_name = current_screen.selected_tag.name
		local next_screen_tag_name = next_screen.selected_tag.name

		for _, t in ipairs(current_screen.tags) do
			local fallback_tag = awful.tag.find_by_name(next_screen, t.name)
			local self_clients = t:clients()
			local other_clients

			if not fallback_tag then
				-- if not available, use first tag
				fallback_tag = next_screen.tags[1]
				other_clients = {}
			else
				other_clients = fallback_tag:clients()
			end

			for _, c in ipairs(self_clients) do
				c:move_to_tag(fallback_tag)
			end

			for _, c in ipairs(other_clients) do
				c:move_to_tag(t)
			end
		end

		awful.tag.find_by_name(next_screen, current_screen_tag_name):view_only()
		awful.tag.find_by_name(current_screen, next_screen_tag_name):view_only()

		current_screen = next_screen
	end
end

awful.spawn("systemctl --user start pywal-restore")
