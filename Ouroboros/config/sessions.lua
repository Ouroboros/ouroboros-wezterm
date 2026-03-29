return function(wezterm, _config)
	local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
	local sep = wezterm.config_dir:find("\\", 1, true) and "\\" or "/"
	local vendor_root = wezterm.config_dir .. sep .. "vendor" .. sep .. "wezterm-sessions"
	local plugin_root = vendor_root .. sep .. "plugin"
	local plugin_path = plugin_root .. sep .. "?.lua"
	local plugin_init_path = plugin_root .. sep .. "?" .. sep .. "init.lua"
	local sessions
	local tab_mod
	local window_mod
	local workspace_mod
	local original_restore_window
	local act = wezterm.action

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
	tab_mod = require("tab")
	window_mod = require("window")
	workspace_mod = require("workspace")
	original_restore_window = window_mod.restore_window

	local function close_tabs_in_window(window)
		local mux_window = window:mux_window()
		local tabs = {}
		for _, tab in ipairs(mux_window:tabs()) do
			table.insert(tabs, tab)
		end

		for _, tab in ipairs(tabs) do
			local pane = tab:active_pane()
			if pane then
				pcall(function()
					window:perform_action(wezterm.action.CloseCurrentTab { confirm = false }, pane)
				end)
			end
		end
	end

	window_mod.restore_window = function(window, win_data)
		local mux_window = window:mux_window()
		local initial_tab_ids = {}
		for _, tab in ipairs(mux_window:tabs()) do
			initial_tab_ids[tab:tab_id()] = true
		end
		local mismatches = original_restore_window(window, win_data)

		if next(initial_tab_ids) ~= nil and #mux_window:tabs() > 1 then
			for _, tab in ipairs(mux_window:tabs()) do
				if initial_tab_ids[tab:tab_id()] then
					pcall(function()
						tab:activate()
						window:perform_action(
							wezterm.action.CloseCurrentTab { confirm = false },
							tab:active_pane()
						)
					end)
				end
			end
		end

		return mismatches
	end

	if is_windows then
		sessions.apply_to_config({ keys = {} }, {
			save_state_dir = "D:\\Dev\\WezTerm\\plugins\\abidibo-wezterm-sessions\\state\\",
		})
	end

	wezterm.on("ouroboros_restore_session", function(window)
		local workspace = window:active_workspace()
		local _, _, mux_window = wezterm.mux.spawn_window({
			workspace = workspace,
		})
		local restore_window = mux_window and mux_window:gui_window()
		if restore_window then
			sessions.restore_state(restore_window)
		end
	end)

	wezterm.on("ouroboros_load_session", function(window, pane)
		local choices = workspace_mod.get_workspaces("D:\\Dev\\WezTerm\\plugins\\abidibo-wezterm-sessions\\state\\")
		local source_window = window
		window:perform_action(
			act.InputSelector({
				action = wezterm.action_callback(function(_, _, id, label)
					if not id or not label then
						return
					end

					local _, _, mux_window = wezterm.mux.spawn_window({
						workspace = id,
					})
					local restore_window = mux_window and mux_window:gui_window()
					if restore_window then
						sessions.restore_state(restore_window)
						close_tabs_in_window(source_window)
					end
				end),
				title = "Choose Workspace",
				description = "Load workspace in a new window. Enter = accept, Esc = cancel, / = filter",
				fuzzy_description = "Filter workspaces: ",
				choices = choices,
				fuzzy = true,
			}),
			pane
		)
	end)
end
