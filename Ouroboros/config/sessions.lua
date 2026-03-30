return function(wezterm, _config)
	local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
	local sep = wezterm.config_dir:find("\\", 1, true) and "\\" or "/"
	local vendor_root = wezterm.config_dir .. sep .. "vendor" .. sep .. "wezterm-sessions"
	local plugin_root = vendor_root .. sep .. "plugin"
	local plugin_path = plugin_root .. sep .. "?.lua"
	local plugin_init_path = plugin_root .. sep .. "?" .. sep .. "init.lua"
	local sessions

	if not package.path:find(plugin_root, 1, true) then
		package.path = table.concat({
			plugin_path,
			plugin_init_path,
			package.path,
		}, ";")
	end

	for _, module_name in ipairs({
		"fs",
		"git",
		"pane",
		"tab",
		"timer",
		"utils",
		"window",
		"workspace",
	}) do
		package.loaded[module_name] = nil
	end

	_G.__OUROBOROS_WEZTERM_SESSIONS_DIR = vendor_root
	sessions = dofile(plugin_root .. sep .. "init.lua")

	if is_windows then
		sessions.apply_to_config({ keys = {} }, {
			save_state_dir = "D:\\Dev\\WezTerm\\plugins\\abidibo-wezterm-sessions\\state\\",
		})
	end
end
