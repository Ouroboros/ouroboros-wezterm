return function(wezterm, config)
  local act = wezterm.action

  config.keys = {
    {
      key = 'c',
      mods = 'CTRL',
      action = wezterm.action_callback(function(window, pane)
        local has_selection = window:get_selection_text_for_pane(pane) ~= ''
        if has_selection then
          window:perform_action(act.CopyTo 'Clipboard', pane)
          window:perform_action(act.ClearSelection, pane)
        else
          window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
        end
      end),
    },
	    { key = 'v',          mods = 'CTRL',  action = act.PasteFrom 'Clipboard' },
	    { key = 'w',          mods = 'CTRL',  action = act.CloseCurrentTab { confirm = false } },
	    {
	      key = 'l',
	      mods = 'CTRL',
	      action = act.Multiple {
	        act.ClearScrollback 'ScrollbackAndViewport',
	        act.SendKey { key = 'l', mods = 'CTRL' },
	      },
	    },
    { key = 'Enter',      mods = 'CTRL',  action = wezterm.action.ToggleFullScreen },
	    { key = 'Enter',      mods = 'SHIFT', action = act.SendString '\x0a' },
	    { key = 'Enter',      mods = 'ALT',   action = wezterm.action.DisableDefaultAssignment },
    { key = 's',          mods = 'CTRL|ALT', action = act({ EmitEvent = "save_session" }) },
	    { key = 'r',          mods = 'CTRL|ALT', action = act({ EmitEvent = "restore_session" }) },
	    { key = 'l',          mods = 'CTRL|ALT', action = act({ EmitEvent = "load_session" }) },
    {
      key = '$',
      mods = 'CTRL|SHIFT',
      action = act.PromptInputLine {
        description = 'Enter new workspace name',
        action = wezterm.action_callback(function(window, _pane, line)
          if line then
            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
          end
        end),
      },
    },
    { key = 't',          mods = 'ALT',   action = wezterm.action.SpawnTab("DefaultDomain") },
    { key = 'm',          mods = 'ALT',   action = wezterm.action.ShowTabNavigator },
    { key = 'n',          mods = 'CTRL|SHIFT', action = wezterm.action.SpawnWindow },
    { key = 'd',          mods = 'ALT',   action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
    { key = 'D',          mods = 'ALT',   action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
    { key = 'h',          mods = 'ALT',   action = wezterm.action.ActivatePaneDirection("Left") },
    { key = 'j',          mods = 'ALT',   action = wezterm.action.ActivatePaneDirection("Down") },
    { key = 'k',          mods = 'ALT',   action = wezterm.action.ActivatePaneDirection("Up") },
    { key = 'l',          mods = 'ALT',   action = wezterm.action.ActivatePaneDirection("Right") },
    { key = 'LeftArrow',  mods = 'ALT',   action = wezterm.action.AdjustPaneSize { "Left", 5 } },
    { key = 'DownArrow',  mods = 'ALT',   action = wezterm.action.AdjustPaneSize { "Down", 5 } },
    { key = 'UpArrow',    mods = 'ALT',   action = wezterm.action.AdjustPaneSize { "Up", 5 } },
    { key = 'RightArrow', mods = 'ALT',   action = wezterm.action.AdjustPaneSize { "Right", 5 } },
    { key = 'L',          mods = 'ALT',   action = wezterm.action.ActivateTabRelative(1) },
    { key = 'H',          mods = 'ALT',   action = wezterm.action.ActivateTabRelative(-1) },
    { key = 'F1',         mods = 'NONE',  action = wezterm.action.ActivateTabRelative(-1) },
    { key = 'F2',         mods = 'NONE',  action = wezterm.action.ActivateTabRelative(1) },
  }

  for i = 1, 9 do
    table.insert(config.keys, {
      key = tostring(i),
      mods = 'CTRL',
      action = act.ActivateTab(i - 1),
    })
  end
end
