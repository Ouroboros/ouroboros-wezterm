local function load_config(name)
	local wezterm = require("wezterm")
	local sep = package.config:sub(1, 1)
	local root = wezterm.config_dir .. sep .. name
	local entry = root .. sep .. "wezterm.lua"
	local old_path = package.path
	local old_config_dir = wezterm.config_dir
	local old_config_file = wezterm.config_file

	wezterm.add_to_config_reload_watch_list(entry)
	wezterm.config_dir = root
	wezterm.config_file = entry
	package.path = table.concat({
		root .. sep .. "?.lua",
		root .. sep .. "?" .. sep .. "init.lua",
		old_path,
	}, ";")

	local ok, result = pcall(dofile, entry)
	package.path = old_path
	wezterm.config_dir = old_config_dir
	wezterm.config_file = old_config_file

	if not ok then
		error(result)
	end

	return result
end

return load_config("Ouroboros")
-- return load_config("KevinSilvester")
