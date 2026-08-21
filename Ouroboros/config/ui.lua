local wezterm = require("wezterm")

local backdrops
local selected_backdrop

local ui = {}
local IMAGE_EXTENSIONS = {
	jpg = true,
	jpeg = true,
	png = true,
	gif = true,
	bmp = true,
	ico = true,
	tiff = true,
	pnm = true,
	dds = true,
	tga = true,
	webp = true,
}
local BACKDROP_BLACKLIST = {
	["/skyrim/alduinwalllarge.jpg"] = true,
	["/アカメが斬る！/akame_ga_kill-15.jpg"] = true,
	["/アカメが斬る！/dayi78q-17248000-6f4a-4e7a-a769-9a0e71387951.jpg"] = true,
	-- ["/skyrim/skyrim_fanart_4k_by_stonez4x-d8fw4n9.jpg"] = true,
	-- ["/skyrim/solitude.jpg"] = true,
	-- ["/英雄傳說 閃之軌跡Ⅳ -the end of saga-/celestialglobe.png"] = true,
}

ui.backdrop_dirs = {
	"E:\\Document\\Images\\アカメが斬る！",
	-- "E:\\Document\\pic\\background",
	-- "C:\\Users\\Arianrhod\\Pictures\\Spotlight Wallpapers",
	-- "C:\\Users\\Arianrhod\\.config\\wezterm\\KevinSilvester\\backdrops",
}

ui.backdrop_rotate_interval_seconds = 60 * 60

ui.mocha = {
	rosewater = "#f5e0dc",
	flamingo = "#f2cdcd",
	pink = "#f5c2e7",
	mauve = "#cba6f7",
	red = "#f38ba8",
	maroon = "#eba0ac",
	peach = "#fab387",
	yellow = "#f9e2af",
	green = "#a6e3a1",
	teal = "#94e2d5",
	sky = "#89dceb",
	sapphire = "#74c7ec",
	blue = "#89b4fa",
	lavender = "#b4befe",
	text = "#cdd6f4",
	subtext1 = "#bac2de",
	subtext0 = "#a6adc8",
	overlay2 = "#9399b2",
	overlay1 = "#7f849c",
	overlay0 = "#6c7086",
	surface2 = "#585b70",
	surface1 = "#45475a",
	surface0 = "#313244",
	base = "#1f1f28",
	mantle = "#181825",
	crust = "#11111b",
}

ui.colors = {
	foreground = ui.mocha.text,
	background = "#000000",
	cursor_bg = ui.mocha.rosewater,
	cursor_border = ui.mocha.rosewater,
	cursor_fg = ui.mocha.crust,
	selection_bg = ui.mocha.surface2,
	selection_fg = ui.mocha.text,
	ansi = {
		"#0C0C0C",
		"#C50F1F",
		"#13A10E",
		"#C19C00",
		"#0037DA",
		"#881798",
		"#3A96DD",
		"#CCCCCC",
	},
	brights = {
		"#767676",
		"#E74856",
		"#16C60C",
		"#F9F1A5",
		"#3B78FF",
		"#B4009E",
		"#61D6D6",
		"#F2F2F2",
	},
	tab_bar = {
		background = "rgba(0, 0, 0, 0.4)",
		active_tab = {
			bg_color = ui.mocha.surface2,
			fg_color = ui.mocha.text,
		},
		inactive_tab = {
			bg_color = ui.mocha.surface0,
			fg_color = ui.mocha.subtext1,
		},
		inactive_tab_hover = {
			bg_color = ui.mocha.surface0,
			fg_color = ui.mocha.text,
		},
		new_tab = {
			bg_color = ui.mocha.base,
			fg_color = ui.mocha.text,
		},
		new_tab_hover = {
			bg_color = ui.mocha.mantle,
			fg_color = ui.mocha.text,
			italic = true,
		},
	},
	visual_bell = ui.mocha.red,
	indexed = {
		[16] = ui.mocha.peach,
		[17] = ui.mocha.rosewater,
	},
	scrollbar_thumb = ui.mocha.surface2,
	split = ui.mocha.overlay0,
	compose_cursor = ui.mocha.flamingo,
}

ui.tab_colors = {
	text_default = { bg = "#45475A", fg = "#1C1B19" },
	text_hover = { bg = "#5D87A3", fg = "#1C1B19" },
	text_active = { bg = "#74C7EC", fg = "#11111B" },
	unseen_default = { bg = "#45475A", fg = "#FFA066" },
	unseen_hover = { bg = "#5D87A3", fg = "#FFA066" },
	unseen_active = { bg = "#74C7EC", fg = "#FFA066" },
	scircle_default = { bg = "rgba(0, 0, 0, 0.4)", fg = "#45475A" },
	scircle_hover = { bg = "rgba(0, 0, 0, 0.4)", fg = "#5D87A3" },
	scircle_active = { bg = "rgba(0, 0, 0, 0.4)", fg = "#74C7EC" },
}

ui.status_colors = {
	backdrop = { fg = ui.mocha.lavender, bg = "rgba(0, 0, 0, 0.4)" },
	date = { fg = ui.mocha.peach, bg = "rgba(0, 0, 0, 0.4)" },
	battery = { fg = ui.mocha.yellow, bg = "rgba(0, 0, 0, 0.4)" },
	separator = { fg = ui.mocha.sapphire, bg = "rgba(0, 0, 0, 0.4)" },
}

ui.backdrop_overlay = "rgba(0, 0, 0, 0.80)"

local function is_image_file(path)
	local ext = path:match("%.([^.]+)$")
	if not ext then
		return false
	end

	return IMAGE_EXTENSIONS[ext:lower()] == true
end

local function is_blacklisted_backdrop(path)
	local normalized = path:gsub("\\", "/"):lower()
	for suffix in pairs(BACKDROP_BLACKLIST) do
		if normalized:sub(-#suffix) == suffix then
			return true
		end
	end

	return false
end

local function collect_backdrops_from_dir(dir, images, visited)
	if not dir or dir == "" or visited[dir] then
		return
	end

	visited[dir] = true

	local ok, entries = pcall(wezterm.read_dir, dir)
	if not ok or not entries then
		return
	end

	for _, entry in ipairs(entries) do
		local is_dir = pcall(wezterm.read_dir, entry)
		if is_dir then
			collect_backdrops_from_dir(entry, images, visited)
		elseif is_image_file(entry) and not is_blacklisted_backdrop(entry) then
			table.insert(images, entry)
		end
	end
end

local function load_backdrops()
	if backdrops ~= nil then
		return backdrops
	end

	math.randomseed(os.time())
	math.random()
	math.random()
	math.random()

	backdrops = {}
	local visited = {}

	for _, dir in ipairs(ui.backdrop_dirs) do
		collect_backdrops_from_dir(dir, backdrops, visited)
	end

	return backdrops
end

local function background_layers_for_file(path)
	if not path then
		return {
			{
				source = { Color = ui.colors.background },
			},
		}
	end

	return {
		{
			source = { File = path },
			horizontal_align = "Center",
		},
		{
			source = { Color = ui.backdrop_overlay },
			height = "120%",
			width = "120%",
			vertical_offset = "-10%",
			horizontal_offset = "-10%",
			opacity = 1,
		},
	}
end

local function pick_random_backdrop()
	local images = load_backdrops()
	if #images == 0 then
		selected_backdrop = nil
		return nil
	end

	if #images == 1 then
		selected_backdrop = images[1]
		return selected_backdrop
	end

	local previous_backdrop = selected_backdrop
	repeat
		selected_backdrop = images[math.random(#images)]
	until selected_backdrop ~= previous_backdrop

	return selected_backdrop
end

function ui.background_layers()
	return background_layers_for_file(pick_random_backdrop())
end

local function window_global_key(prefix, window)
	local ok, window_id = pcall(function()
		return window:window_id()
	end)

	if ok and window_id then
		return prefix .. tostring(window_id)
	end

	return prefix .. tostring(window)
end

function ui.apply_random_background(window)
	if not window then
		return
	end

	local overrides = window:get_config_overrides() or {}
	overrides.background = ui.background_layers()

	if wezterm.GLOBAL then
		wezterm.GLOBAL[window_global_key("ouroboros_background_rotation_ignore_", window)] = true
	end

	window:set_config_overrides(overrides)
end

function ui.start_background_rotation(window)
	local can_rotate = ui.backdrop_rotate_interval_seconds > 0
		and wezterm.GLOBAL
		and wezterm.time
		and wezterm.time.call_after

	if not can_rotate or not window then
		return
	end

	local global = wezterm.GLOBAL
	local generation_key = window_global_key("ouroboros_background_rotation_generation_", window)
	global[generation_key] = (global[generation_key] or 0) + 1
	local generation = global[generation_key]

	local function tick()
		if global[generation_key] ~= generation then
			return
		end

		ui.apply_random_background(window)

		wezterm.time.call_after(ui.backdrop_rotate_interval_seconds, tick)
	end

	wezterm.time.call_after(ui.backdrop_rotate_interval_seconds, tick)
end

function ui.start_background_rotation_for_all_windows()
	if not wezterm.gui or not wezterm.gui.gui_windows then
		return
	end

	local ok, windows = pcall(wezterm.gui.gui_windows)
	if not ok or not windows then
		return
	end

	for _, window in ipairs(windows) do
		ui.start_background_rotation(window)
	end
end

function ui.register_background_rotation()
	if not wezterm.on then
		return
	end

	wezterm.on("gui-attached", function()
		ui.start_background_rotation_for_all_windows()
	end)

	wezterm.on("window-config-reloaded", function(window, _pane)
		local ignore_key = window_global_key("ouroboros_background_rotation_ignore_", window)
		if wezterm.GLOBAL and wezterm.GLOBAL[ignore_key] then
			wezterm.GLOBAL[ignore_key] = nil
			return
		end

		ui.apply_random_background(window)
		ui.start_background_rotation(window)
	end)
end

function ui.clean_process_name(proc)
	local basename = string.gsub(proc or "", "(.*[/\\\\])(.*)", "%2")
	return basename:gsub("%.exe$", "")
end

function ui.current_backdrop_name()
	if not selected_backdrop then
		return nil
	end

	local basename = selected_backdrop:match("([^/\\\\]+)$") or selected_backdrop
	return basename:gsub("%.[^.]+$", "")
end

return ui
