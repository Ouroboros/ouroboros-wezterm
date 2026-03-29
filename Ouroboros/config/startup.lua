return function(wezterm, config)
	local mux = wezterm.mux

	wezterm.on("gui-attached", function(_domain)
		local workspace = mux.get_active_workspace()
		local screen = wezterm.gui.screens().active
		for _, window in ipairs(mux.all_windows()) do
			if window:get_workspace() == workspace then
				local gui_window = window:gui_window()
				if gui_window then
					local dims = gui_window:get_dimensions()
					local x = screen.x + math.floor((screen.width - dims.pixel_width) / 2)
					local y = screen.y + math.floor((screen.height - dims.pixel_height) / 2)
					gui_window:set_position(x, y)
				end
			end
		end
	end)
end
