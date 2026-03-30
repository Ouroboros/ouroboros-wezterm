return function(wezterm, config)
	local ui = require("config.ui")
	local nf = wezterm.nerdfonts
	local LEFT = nf.ple_left_half_circle_thick
	local RIGHT = nf.ple_right_half_circle_thick
	local ADMIN = nf.md_shield_half_full
	local LINUX = nf.cod_terminal_linux
	local ENABLE_DYNAMIC_TAB_TITLE = false
	local IGNORED_PROCESSES = {
		wsl = true,
		wslhost = true,
		wezterm = true,
		bash = true,
		zsh = true,
		sh = true,
		fish = true,
		pwsh = true,
		powershell = true,
		cmd = true,
		nu = true,
	}

	local function cwd_name_from_value(cwd)
		if not cwd then
			return nil
		end

		local path = cwd.file_path or cwd
		if type(path) ~= "string" or path == "" then
			return nil
		end

		path = path:gsub("[/\\]+$", "")
		return path:match("([^/\\]+)$")
	end

	local function resolved_title(process_name, cwd_name, pane_title)
		local process_key = (process_name or ""):lower()

		if pane_title == "Debug" then
			return nf.fa_bug .. " DEBUG"
		end

		if pane_title and pane_title:match("^InputSelector:") then
			return pane_title:gsub("^InputSelector:", "🔭")
		end

		if process_name and process_name ~= "" and not IGNORED_PROCESSES[process_key] then
			return process_name
		end

		if cwd_name and cwd_name ~= "" then
			return cwd_name
		end

		if process_name and process_name ~= "" then
			return process_name
		end

		return pane_title or "Terminal"
	end

	local function simplified_default_title(pane_title)
		if not pane_title or pane_title == "" then
			return "Terminal"
		end

		local cwd = pane_title:match("^[^:]+:%s*(.+)$")
		if cwd and cwd ~= "" then
			if cwd == "~" or cwd == "/" then
				return cwd
			end

			cwd = cwd:gsub("[/\\]+$", "")
			local leaf = cwd:match("([^/\\]+)$")
			if leaf and leaf ~= "" then
				return leaf
			end

			return cwd
		end

		return pane_title
	end

	local function tab_title(tab)
		if not ENABLE_DYNAMIC_TAB_TITLE then
			local pane_title = simplified_default_title(tab.active_pane.title)
			return string.format("%d: %s", tab.tab_index + 1, pane_title)
		end

		local pane_title = tab.active_pane.title or ""
		local process_name = ui.clean_process_name(tab.active_pane.foreground_process_name)
		local cwd_name = nil
		local title = resolved_title(process_name, cwd_name, pane_title)

		return string.format("%d: %s", tab.tab_index + 1, title)
	end

	local function state_colors(tab, hover)
		if tab.is_active then
			return ui.tab_colors.text_active, ui.tab_colors.scircle_active
		end

		if hover then
			return ui.tab_colors.text_hover, ui.tab_colors.scircle_hover
		end

		return ui.tab_colors.text_default, ui.tab_colors.scircle_default
	end

	wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, hover, max_width)
		local text_color, edge_color = state_colors(tab, hover)
		local process_name = ""
		local items = {
			{ Background = { Color = edge_color.bg } },
			{ Foreground = { Color = edge_color.fg } },
			{ Attribute = { Intensity = "Bold" } },
			{ Text = LEFT },
			{ Background = { Color = text_color.bg } },
			{ Foreground = { Color = text_color.fg } },
		}
		local title = tab_title(tab)
		local left_width = wezterm.column_width(LEFT)
		local right_width = wezterm.column_width(RIGHT)
		local prefix_text = ""
		local suffix_text = " "

		if ENABLE_DYNAMIC_TAB_TITLE and process_name:match("^wsl") then
			prefix_text = LINUX
			table.insert(items, { Text = prefix_text })
		elseif tab.active_pane.title:match("^Administrator: ") or tab.active_pane.title:match("%(Admin%)") then
			prefix_text = ADMIN
			table.insert(items, { Text = prefix_text })
		end

		local inset = left_width
			+ right_width
			+ wezterm.column_width(prefix_text)
			+ wezterm.column_width(suffix_text)
		local title_width = math.max(1, max_width - inset)
		title = wezterm.truncate_right(title, title_width)
		table.insert(items, { Attribute = { Intensity = "Bold" } })
		table.insert(items, { Text = "" .. title })
		table.insert(items, { Background = { Color = text_color.bg } })
		table.insert(items, { Foreground = { Color = text_color.fg } })
		table.insert(items, { Text = suffix_text })

		table.insert(items, { Background = { Color = edge_color.bg } })
		table.insert(items, { Foreground = { Color = edge_color.fg } })
		table.insert(items, { Text = RIGHT })
		table.insert(items, "ResetAttributes")
		return items
	end)
end
