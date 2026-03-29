return function(wezterm, _config)
	local sessions = wezterm.plugin.require("https://github.com/abidibo/wezterm-sessions")
	local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
	local tab_mod = require("tab")
	local original_restore_tab = tab_mod.restore_tab

	require("fs").is_windows = is_windows

	tab_mod.restore_tab = function(window, tab_data)
		local saved_title = tab_data.title
		tab_data.title = nil
		local tab, mismatches = original_restore_tab(window, tab_data)
		tab_data.title = saved_title
		return tab, mismatches
	end

	if is_windows then
		sessions.apply_to_config({ keys = {} }, {
			save_state_dir = "D:\\Dev\\WezTerm\\plugins\\abidibo-wezterm-sessions\\state\\",
		})
	end
end
