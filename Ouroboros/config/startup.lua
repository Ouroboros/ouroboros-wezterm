return function(wezterm, config)
	local mux = wezterm.mux

	wezterm.on("gui-attached", function(_domain)
		local workspace = mux.get_active_workspace()
		local screen = wezterm.gui.screens().active
		for _, window in ipairs(mux.all_windows()) do
			if window:get_workspace() == workspace then
				local gui_window = window:gui_window()
				if gui_window then
					gui_window:maximize()
				end
			end
		end
	end)
end
