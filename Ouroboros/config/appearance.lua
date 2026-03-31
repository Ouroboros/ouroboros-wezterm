return function(wezterm, config)
	local ui = require("config.ui")
	local config_root = wezterm.config_dir:match("^(.*)[/\\][^/\\]+$") or wezterm.config_dir
	local default_wsl_domains = {
		"WSL:Ubuntu-22.04",
		"WSL:Ubuntu",
	}

	-- 默认的长宽
	config.initial_cols = 161
	config.initial_rows = 35

	config.window_decorations = "RESIZE"
	config.font = wezterm.font("JetBrains Mono", { weight = "Bold", italic = true })
	config.font_size = 12
	config.freetype_load_target = "Normal"
	config.freetype_render_target = "Normal"

	config.animation_fps = 120
	config.cursor_blink_ease_in = "EaseOut"
	config.cursor_blink_ease_out = "EaseOut"
	config.default_cursor_style = "BlinkingBlock"
	config.cursor_blink_rate = 650
	config.underline_thickness = "1.5pt"

	config.colors = ui.colors
	config.background = ui.background_layers()

	config.enable_scroll_bar = true
	config.enable_tab_bar = true
	config.use_fancy_tab_bar = true
	config.hide_tab_bar_if_only_one_tab = false
		config.tab_max_width = 50
	config.show_tab_index_in_tab_bar = false

	config.command_palette_fg_color = ui.mocha.lavender
	config.command_palette_bg_color = ui.mocha.crust
	config.command_palette_font_size = 12
	config.command_palette_rows = 25

	config.window_padding = {
		left = 0,
		right = 0,
		top = 10,
		bottom = 7.5,
	}
	config.window_close_confirmation = "NeverPrompt"
	config.window_frame = {
		active_titlebar_bg = "#090909",
		font_size = 12,
	}
	config.visual_bell = {
		fade_in_function = "EaseIn",
		fade_in_duration_ms = 250,
		fade_out_function = "EaseOut",
		fade_out_duration_ms = 250,
		target = "CursorColor",
	}

	config.wsl_domains = wezterm.default_wsl_domains()
	local matched_default_wsl_domain = nil
	for _, domain in ipairs(config.wsl_domains) do
		for _, candidate in ipairs(default_wsl_domains) do
			if domain.name == candidate then
				domain.default_cwd = config_root
				if not matched_default_wsl_domain then
					matched_default_wsl_domain = candidate
				end
				break
			end
		end
	end
	if matched_default_wsl_domain then
		config.default_domain = matched_default_wsl_domain
	end
end
