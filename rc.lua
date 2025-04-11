pcall(require, "luarocks.loader")

local gears = require("gears")
awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")

local bling = require("bling")
local lain = require("lain")

if awesome.startup_errors then
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Oops, there were errors during startup!",
		text = awesome.startup_errors,
	})
end

do
	local in_error = false
	awesome.connect_signal("debug::error", function(err)
		if in_error then
			return
		end
		in_error = true

		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Oops, an error happened!",
			text = tostring(err),
		})
		in_error = false
	end)
end

beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/zenburn/theme.lua")

local terminal = "wezterm"
local editor = os.getenv("EDITOR") or "nvim"
local editor_cmd = terminal .. " -e " .. editor

local modkey = "Mod4"

awful.layout.layouts = {
	awful.layout.suit.tile,
	awful.layout.suit.spiral,
	awful.layout.suit.max,
}

local mytextclock = wibox.widget.textclock("%a %b %d, %I:%M %p")
local month_calendar = awful.widget.calendar_popup.month()
month_calendar:attach(mytextclock, "tr")

local myhotkeyPopup = hotkeys_popup.widget.new({ height = 1300, width = 1400 })

local taglist_buttons = gears.table.join(
	awful.button({}, 1, function(t)
		t:view_only()
	end),
	awful.button({ modkey }, 1, function(t)
		if client.focus then
			client.focus:move_to_tag(t)
		end
	end),
	awful.button({}, 3, awful.tag.viewtoggle),
	awful.button({ modkey }, 3, function(t)
		if client.focus then
			client.focus:toggle_tag(t)
		end
	end),
	awful.button({}, 4, function(t)
		awful.tag.viewnext(t.screen)
	end),
	awful.button({}, 5, function(t)
		awful.tag.viewprev(t.screen)
	end)
)

local tasklist_buttons = gears.table.join(
	awful.button({}, 1, function(c)
		if c == client.focus then
			c.minimized = true
		else
			c:emit_signal("request::activate", "tasklist", { raise = true })
		end
	end),
	awful.button({}, 4, function()
		awful.client.focus.byidx(1)
	end),
	awful.button({}, 5, function()
		awful.client.focus.byidx(-1)
	end)
)

local function set_wallpaper(s)
	-- Wallpaper
	if beautiful.wallpaper then
		local wallpaper = beautiful.wallpaper
		-- If wallpaper is a function, call it with the screen
		if type(wallpaper) == "function" then
			wallpaper = wallpaper(s)
		end
		gears.wallpaper.maximized(wallpaper, s, true)
	end
end

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
	-- Wallpaper
	set_wallpaper(s)

	-- Each screen has its own tag table.
	awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

	-- Create a promptbox for each screen
	s.mypromptbox = awful.widget.prompt()
	-- Create an imagebox widget which will contain an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	s.mylayoutbox = awful.widget.layoutbox(s)
	s.mylayoutbox:buttons(gears.table.join(
		awful.button({}, 1, function()
			awful.layout.inc(1)
		end),
		awful.button({}, 3, function()
			awful.layout.inc(-1)
		end),
		awful.button({}, 4, function()
			awful.layout.inc(1)
		end),
		awful.button({}, 5, function()
			awful.layout.inc(-1)
		end)
	))
	-- Create a taglist widget
	s.mytaglist = awful.widget.taglist({
		screen = s,
		filter = awful.widget.taglist.filter.noempty,
		buttons = taglist_buttons,
		style = {
			shape = gears.shape.rectangle,
		},
		layout = {
			spacing = 5,
			layout = wibox.layout.fixed.horizontal,
		},
	})

	-- Create a tasklist widget
	s.mytasklist = awful.widget.tasklist({
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = tasklist_buttons,
		layout = {
			spacing = 10,
			spacing_widget = {
				{
					forced_width = 5,
					forced_height = 24,
					thickness = 1,
					color = "#777777",
					widget = wibox.widget.separator,
				},
				valign = "center",
				halign = "center",
				widget = wibox.container.place,
			},
			layout = wibox.layout.flex.horizontal,
		},
	})

	-- Create the wibox
	s.mywibox = awful.wibar({ position = "bottom", screen = s, height = 25 })

	local mysystemtray = wibox.widget.systray()
	-- Add widgets to the wibox
	local ram = lain.widget.mem({
		settings = function()
			widget:set_markup(
				lain.util.markup.fontfg(
					beautiful.font,
					"#b8bb26",
					"󰍛 " .. math.floor(mem_now.used / 1024 * 10) / 10 .. "G"
				)
			)
		end,
	})
	local cpu = lain.widget.cpu({
		settings = function()
			widget:set_markup(lain.util.markup.fontfg(beautiful.font, "#83a598", "󰻠 " .. cpu_now.usage .. "%"))
		end,
	})
	-- Net
	local netdowninfo = wibox.widget.textbox()
	local netupinfo = lain.widget.net({
		units = 1024 * 1024,
		settings = function()
			widget:set_markup(lain.util.markup.fontfg(beautiful.font, "#d3869b", " " .. net_now.sent .. "Mb"))
			netdowninfo:set_markup(
				lain.util.markup.fontfg(beautiful.font, "#8ec07c", " " .. net_now.received .. "Mb")
			)
		end,
	})
	local fsroothome = lain.widget.fs({
		settings = function()
			widget:set_text(
				"/ - "
					.. string.format("%.1f", fs_now["/"].used)
					.. "/"
					.. string.format("%.1f", fs_now["/"].size)
					.. " "
					.. fs_now["/"].units
			)
		end,
	})
	local mytemp = lain.widget.temp({ format = "cpu %.1f" })

	s.mywibox:setup({
		layout = wibox.layout.align.horizontal,
		expand = "none",
		{
			layout = wibox.layout.fixed.horizontal,
			s.mytaglist,
			s.mypromptbox,
			s.mytasklist,
		},
		{ layout = wibox.layout.fixed.horizontal, mytextclock },
		{
			layout = wibox.layout.fixed.horizontal,
			spacing = 10,
			mytemp.widget,
			fsroothome.widget,
			netupinfo.widget,
			netdowninfo,
			cpu,
			ram,
			mysystemtray,
			s.mylayoutbox,
		},
	})
end)

local globalkeys = gears.table.join(
	awful.key({ modkey }, "s", function()
		myhotkeyPopup:show_help()
	end, { description = "show help", group = "awesome" }),
	awful.key({ modkey }, "Left", awful.tag.viewprev, { description = "view previous", group = "tag" }),
	awful.key({ modkey }, "Right", awful.tag.viewnext, { description = "view next", group = "tag" }),
	awful.key({ modkey }, "Escape", awful.tag.history.restore, { description = "go back", group = "tag" }),
	awful.key({ modkey }, "j", function()
		awful.client.focus.byidx(1)
	end, { description = "focus next by index", group = "client" }),

	awful.key({ modkey }, "k", function()
		awful.client.focus.byidx(-1)
	end, { description = "focus previous by index", group = "client" }),

	-- Layout manipulation
	awful.key({ modkey, "Shift" }, "j", function()
		awful.client.swap.byidx(1)
	end, { description = "swap with next client by index", group = "client" }),
	awful.key({ modkey, "Shift" }, "k", function()
		awful.client.swap.byidx(-1)
	end, { description = "swap with previous client by index", group = "client" }),
	awful.key({ modkey, "Control" }, "j", function()
		awful.screen.focus_relative(1)
	end, { description = "focus the next screen", group = "screen" }),
	awful.key({ modkey, "Control" }, "k", function()
		awful.screen.focus_relative(-1)
	end, { description = "focus the previous screen", group = "screen" }),
	awful.key({ modkey }, "u", awful.client.urgent.jumpto, { description = "jump to urgent client", group = "client" }),
	awful.key({ modkey }, "Tab", function()
		awful.client.focus.history.previous()
		if client.focus then
			client.focus:raise()
		end
	end, { description = "go back", group = "client" }),

	-- Standard program
	awful.key({ modkey }, "Return", function()
		awful.spawn(terminal)
	end, { description = "open a terminal", group = "launcher" }),
	awful.key({ modkey, "Shift" }, "r", awesome.restart, { description = "reload awesome", group = "awesome" }),
	awful.key({ modkey, "Control" }, "e", awesome.quit, { description = "Exit awesome", group = "awesome" }),
	awful.key({ modkey }, "l", function()
		awful.client.focus.bydirection("right")
	end, { description = "go to left client", group = "layout" }),

	awful.key({ modkey }, "h", function()
		awful.client.focus.bydirection("left")
	end, { description = "go to right client", group = "layout" }),

	awful.key({ modkey, "Shift" }, "h", function()
		awful.tag.incnmaster(1, nil, true)
	end, { description = "increase the number of master clients", group = "layout" }),
	awful.key({ modkey, "Shift" }, "l", function()
		awful.tag.incnmaster(-1, nil, true)
	end, { description = "decrease the number of master clients", group = "layout" }),
	awful.key({ modkey, "Control" }, "h", function()
		awful.tag.incmwfact(-0.05)
	end, { description = "increase the number of columns", group = "layout" }),
	awful.key({ modkey, "Control" }, "l", function()
		awful.tag.incmwfact(0.05)
	end, { description = "decrease the number of columns", group = "layout" }),
	awful.key({ modkey }, "space", function()
		awful.layout.inc(1)
	end, { description = "select next", group = "layout" }),

	awful.key({ modkey }, "w", function()
		local curr_screen = awful.screen.focused()
		if awful.layout.get(curr_screen) == awful.layout.suit.max then
			awful.layout.set(awful.layout.suit.tile)
			return
		end
		awful.layout.set(awful.layout.suit.max)
	end, { description = "Toggle Max Layout", group = "layout" }),

	awful.key({ modkey, "Control" }, "space", function()
		awful.layout.inc(-1)
	end, { description = "select previous", group = "layout" }),

	awful.key({ modkey, "Control" }, "n", function()
		local c = awful.client.restore()
		-- Focus restored client
		if c then
			c:emit_signal("request::activate", "key.unminimize", { raise = true })
		end
	end, { description = "restore minimized", group = "client" }),

	awful.key({ modkey }, "x", function()
		awful.prompt.run({
			prompt = "Run Lua code: ",
			textbox = awful.screen.focused().mypromptbox.widget,
			exe_callback = awful.util.eval,
			history_path = awful.util.get_cache_dir() .. "/history_eval",
		})
	end, { description = "lua execute prompt", group = "awesome" }),

	awful.key({ modkey }, "d", function()
		awful.spawn("rofi -modi drun -show drun -theme ~/.config/rofi/gruvbox.rasi")
	end, { description = "show rofi", group = "Launcher" }),

	awful.key({ modkey }, "Print", function()
		awful.spawn("flameshot gui")
	end, { description = "send test notification", group = "awesome" }),

	awful.key({ modkey }, "o", function()
		awful.spawn.with_shell("/home/arshad/.local/bin/calc")
	end, { description = "send test notification", group = "awesome" }),

	awful.key({ modkey, "Shift" }, "o", function()
		awful.spawn("killall calc")
	end, { description = "send test notification", group = "awesome" }),

	awful.key({ modkey, "Control" }, "c", function()
		awful.spawn("gnome-calculator", { floating = true })
	end, { description = "Open Calculator", group = "Apps" }),

	awful.key({ modkey, "Control" }, "b", function()
		awful.spawn("blueman-manager", { floating = true })
	end, { description = "Open Bluetooth Settings", group = "Apps" }),

	awful.key({ modkey, "Control" }, "m", function()
		awful.spawn("pavucontrol", { floating = true })
	end, { description = "Open pavucontrol", group = "Apps" }),

	awful.key({ modkey }, "F2", function()
		awful.spawn("firefox-developer-edition")
	end, { description = "Open Firefox", group = "Apps" }),

	awful.key({ modkey }, "F3", function()
		awful.spawn("pcmanfm")
	end, { description = "Open File Manager", group = "Apps" }),

	awful.key({ modkey }, "F4", function()
		awful.spawn.with_shell("EDITOR=nvim wezterm start ranger")
	end, { description = "Open File Manager", group = "Apps" }),

	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn("pamixer -d 5")
		local handle = io.popen("pamixer --get-volume-human")
		local vol = handle:read("*a")
		handle:close()
		naughty.notify({
			text = vol,
			timeout = 1,
		})
	end, { description = "Decrease Volume", group = "Sound" }),

	awful.key({}, "XF86AudioRaiseVolume", function()
		awful.spawn("pamixer -i 5")
		local handle = io.popen("pamixer --get-volume-human")
		local vol = handle:read("*a")
		handle:close()
		naughty.notify({
			text = vol,
			timeout = 1,
		})
	end, { description = "Increase Volume", group = "Sound" }),

	awful.key({}, "XF86AudioPlay", function()
		awful.spawn("playerctl play-pause")
	end, { description = "play/pause", group = "Media" }),

	awful.key({}, "XF86AudioNext", function()
		awful.spawn("playerctl next")
	end, { description = "next", group = "Media" }),

	awful.key({}, "XF86AudioPrev", function()
		awful.spawn("playerctl previous")
	end, { description = "previous", group = "Media" }),

	awful.key({ modkey }, "b", function()
		awful.spawn.with_shell("~/.local/bin/cycle_sinks.sh")
	end, { description = "Change default Audio Output", group = "Sound" }),

	awful.key({ modkey }, "0", function()
		awful.prompt.run({
			prompt = "PRESS: Shutdown(Shift+s)| suspend(s) | Reboot (r) ",
			hooks = {
				{
					{},
					"s",
					function()
						awful.spawn("systemctl suspend")
					end,
				},
				{
					{ "Shift" },
					"S",
					function()
						awful.spawn("systemctl poweroff")
					end,
				},
				{
					{},
					"r",
					function()
						awful.spawn("systemctl reboot")
					end,
				},
			},
			textbox = awful.screen.focused().mypromptbox.widget,
		})
	end, { description = "Power Menu", group = "Launcher" })
)

local clientkeys = gears.table.join(

	awful.key({ modkey }, "f", function(c)
		c.fullscreen = not c.fullscreen
		c:raise()
	end, { description = "toggle fullscreen", group = "client" }),

	awful.key({ modkey, "Shift" }, "q", function(c)
		c:kill()
	end, { description = "close", group = "client" }),

	awful.key(
		{ modkey, "Shift" },
		"space",
		awful.client.floating.toggle,
		{ description = "toggle floating", group = "client" }
	),

	awful.key({ modkey, "Shift" }, "Return", function(c)
		c:swap(awful.client.getmaster())
	end, { description = "move to master", group = "client" }),

	-- awful.key({ modkey }, "o", function(c)
	-- 	c:move_to_screen()
	-- end, { description = "move to screen", group = "client" }),

	awful.key({ modkey }, "t", function(c)
		c.ontop = not c.ontop
	end, { description = "toggle keep on top", group = "client" }),

	awful.key({ modkey }, "n", function(c)
		-- The client currently has the input focus, so it cannot be
		-- minimized, since minimized clients can't have the focus.
		c.minimized = true
	end, { description = "minimize", group = "client" }),

	awful.key({ modkey }, "m", function(c)
		c.maximized = not c.maximized
		c:raise()
	end, { description = "(un)maximize", group = "client" }),

	-- awful.key({ modkey, "Control" }, "m", function(c)
	-- 	c.maximized_vertical = not c.maximized_vertical
	-- 	c:raise()
	-- end, { description = "(un)maximize vertically", group = "client" }),

	awful.key({ modkey, "Shift" }, "m", function(c)
		c.maximized_horizontal = not c.maximized_horizontal
		c:raise()
	end, { description = "(un)maximize horizontally", group = "client" })
)

for i = 1, 9 do
	globalkeys = gears.table.join(
		globalkeys,
		-- View tag only.
		awful.key({ modkey }, "#" .. i + 9, function()
			local screen = awful.screen.focused()
			local tag = screen.tags[i]
			if tag then
				tag:view_only()
			end
		end, { description = "view tag #" .. i, group = "tag" }),
		-- Toggle tag display.
		awful.key({ modkey, "Control" }, "#" .. i + 9, function()
			local screen = awful.screen.focused()
			local tag = screen.tags[i]
			if tag then
				awful.tag.viewtoggle(tag)
			end
		end, { description = "toggle tag #" .. i, group = "tag" }),
		-- Move client to tag.
		awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
			if client.focus then
				local tag = client.focus.screen.tags[i]
				if tag then
					client.focus:move_to_tag(tag)
					tag:view_only()
				end
			end
		end, { description = "move focused client to tag #" .. i, group = "tag" }),
		-- Toggle tag on focused client.
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function()
			if client.focus then
				local tag = client.focus.screen.tags[i]
				if tag then
					client.focus:toggle_tag(tag)
				end
			end
		end, { description = "toggle focused client on tag #" .. i, group = "tag" })
	)
end

local clientbuttons = gears.table.join(
	awful.button({}, 1, function(c)
		c:emit_signal("request::activate", "mouse_click", { raise = true })
	end),
	awful.button({ modkey }, 1, function(c)
		c:emit_signal("request::activate", "mouse_click", { raise = true })
		awful.mouse.client.move(c)
	end),
	awful.button({ modkey }, 3, function(c)
		c:emit_signal("request::activate", "mouse_click", { raise = true })
		awful.mouse.client.resize(c)
	end)
)

root.keys(globalkeys)

awful.rules.rules = {
	-- All clients will match this rule.
	{
		rule = {},
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			raise = true,
			keys = clientkeys,
			buttons = clientbuttons,
			screen = awful.screen.preferred,
			placement = awful.placement.no_overlap + awful.placement.no_offscreen,
		},
	},

	-- Floating clients.
	{
		rule_any = {
			instance = {
				"DTA", -- Firefox addon DownThemAll.
				"copyq", -- Includes session name in class.
				"pinentry",
			},
			class = {
				"Arandr",
				"Blueman-manager",
				"Gpick",
				"Kruler",
				"MessageWin", -- kalarm.
				"Sxiv",
				"Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
				"Wpa_gui",
				"veromix",
				"xtightvncviewer",
			},
			-- Note that the name property shown in xprop might be set slightly after creation of the client
			-- and the name shown there might not match defined rules here.
			name = {
				"Event Tester", -- xev.
			},
			role = {
				"AlarmWindow", -- Thunderbird's calendar.
				"ConfigManager", -- Thunderbird's about:config.
				"pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
			},
		},
		properties = { floating = true },
	},

	-- Add titlebars to normal clients and dialogs
	{ rule_any = { type = { "normal" } }, properties = { titlebars_enabled = false } },
	{ rule_any = { type = { "dialog" } }, properties = { titlebars_enabled = true } },

	{
		rule = { class = "DBeaver" },
		properties = { screen = 1, tag = "4" },
	},
	{
		rule = { class = "Postman" },
		properties = { screen = 1, tag = "3" },
	},
	{
		rule = { class = "firefox" },
		properties = { screen = 1, tag = "2", border_width = 0 },
	},
	{
		rule = { class = "zoom" },
		properties = { screen = 1, tag = "9" },
	},
	{ rule = { class = "Brave-browser" }, properties = { screen = 1, tag = "2", border_width = 0, floating = true } },
}

client.connect_signal("manage", function(c)
	if not awesome.startup then
		awful.client.setslave(c)
	end

	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

client.connect_signal("request::titlebars", function(c)
	-- buttons for the titlebar
	local buttons = gears.table.join(
		awful.button({}, 1, function()
			c:emit_signal("request::activate", "titlebar", { raise = true })
			awful.mouse.client.move(c)
		end),
		awful.button({}, 3, function()
			c:emit_signal("request::activate", "titlebar", { raise = true })
			awful.mouse.client.resize(c)
		end)
	)

	awful.titlebar(c):setup({
		{
			-- Left
			awful.titlebar.widget.iconwidget(c),
			buttons = buttons,
			layout = wibox.layout.fixed.horizontal,
		},
		{
			-- Middle
			{
				-- Title
				align = "center",
				widget = awful.titlebar.widget.titlewidget(c),
			},
			buttons = buttons,
			layout = wibox.layout.flex.horizontal,
		},
		{
			-- Right
			awful.titlebar.widget.floatingbutton(c),
			awful.titlebar.widget.maximizedbutton(c),
			awful.titlebar.widget.stickybutton(c),
			awful.titlebar.widget.ontopbutton(c),
			awful.titlebar.widget.closebutton(c),
			layout = wibox.layout.fixed.horizontal(),
		},
		layout = wibox.layout.align.horizontal,
	})
end)

client.connect_signal("mouse::enter", function(c)
	c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("focus", function(c)
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)

awful.spawn.with_shell(
	'if (xrdb -query | grep -q "^awesome\\.started:\\s*true$"); then exit; fi;'
		.. 'xrdb -merge <<< "awesome.started:true";'
		-- list each of your autostart commands, followed by ; inside single quotes, followed by ..
		.. "dex --environment Awesome --autostart"
)

awful.spawn.once("lxpolkit")
awful.spawn.once("kdeconnect-indicator")
