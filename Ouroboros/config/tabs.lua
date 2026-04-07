return function(wezterm, config)
	local ui = require("config.ui")
	local nf = wezterm.nerdfonts
	local SOLID_LEFT_ARROW = utf8.char(0xe0ba)
	local SOLID_LEFT_MOST = utf8.char(0x2588)
	local SOLID_RIGHT_ARROW = utf8.char(0xe0bc)
	local LEFT = nf.ple_left_half_circle_thick
	local RIGHT = nf.ple_right_half_circle_thick
	local ADMIN = nf.md_shield_half_full
	local LINUX = nf.cod_terminal_linux
	local SUP_IDX = { "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "¹⁰", "¹¹", "¹²", "¹³", "¹⁴", "¹⁵", "¹⁶", "¹⁷", "¹⁸", "¹⁹", "²⁰" }
	local SUB_IDX = { "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉", "₁₀", "₁₁", "₁₂", "₁₃", "₁₄", "₁₅", "₁₆", "₁₇", "₁₈", "₁₉", "₂₀" }
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

	local function tab_display_title(tab)
		if not ENABLE_DYNAMIC_TAB_TITLE then
			return simplified_default_title(tab.active_pane.title)
		end

		local pane_title = tab.active_pane.title or ""
		local process_name = ui.clean_process_name(tab.active_pane.foreground_process_name)
		local cwd_name = nil
		return resolved_title(process_name, cwd_name, pane_title)
	end

	local function tab_title(tab)
		return string.format("%d: %s", tab.tab_index + 1, tab_display_title(tab))
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

	local function is_admin_title(pane_title)
		return pane_title:match("^Administrator: ") or pane_title:match("%(Admin%)")
	end

	local function tab_sub_index(tab_index)
		return SUB_IDX[tab_index + 1] or tostring(tab_index + 1)
	end

	local function pane_sup_index(pane_index)
		return SUP_IDX[pane_index + 1] or tostring(pane_index + 1)
	end

	local function render_capsule_style(tab, hover, max_width)
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
		elseif is_admin_title(tab.active_pane.title) then
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
	end

	local POWERLINE_TAB_BAR_COLORS = {
		background = "#121212",
		new_tab = { bg_color = "#121212", fg_color = "#FCE8C3", intensity = "Bold" },
		new_tab_hover = { bg_color = "#121212", fg_color = "#FBB829", intensity = "Bold" },
		active_tab = { bg_color = "#121212", fg_color = "#FCE8C3" },
	}

	local function render_powerline_style(tab, hover, max_width)
		local edge_background = "#121212"
		local background = "#4E4E4E"
		local foreground = "#1C1B19"
		local dim_foreground = "#3A3A3A"

		if tab.is_active then
			background = "#FBB829"
			foreground = "#1C1B19"
		elseif hover then
			background = "#FF8700"
			foreground = "#1C1B19"
		end

		local edge_foreground = background
		local left_arrow = SOLID_LEFT_ARROW
		if tab.tab_index == 0 then
			left_arrow = SOLID_LEFT_MOST
		end

		local tab_id = tab_sub_index(tab.tab_index)
		local pane_id = pane_sup_index(tab.active_pane.pane_index or 0)
		local admin_text = ""
		if is_admin_title(tab.active_pane.title) then
			admin_text = " " .. ADMIN
		end

		local inset = wezterm.column_width(left_arrow)
			+ wezterm.column_width(tab_id)
			+ wezterm.column_width(SOLID_RIGHT_ARROW)
			+ wezterm.column_width(" ")
			+ wezterm.column_width(admin_text)
			+ wezterm.column_width(" " .. pane_id)
		local title_width = math.max(1, max_width - inset)
		local title = " " .. wezterm.truncate_right(tab_display_title(tab), title_width) .. admin_text

		return {
			{ Attribute = { Intensity = "Bold" } },
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = left_arrow },
			{ Background = { Color = background } },
			{ Foreground = { Color = foreground } },
			{ Text = tab_id },
			{ Text = title },
			{ Foreground = { Color = dim_foreground } },
			{ Text = " " .. pane_id },
			{ Background = { Color = edge_background } },
			{ Foreground = { Color = edge_foreground } },
			{ Text = SOLID_RIGHT_ARROW },
			{ Attribute = { Intensity = "Normal" } },
		}
	end

	local STYLES = {
		-- Rounded capsule tabs using the KevinSilvester-inspired Catppuccin palette.
		capsule = {
			tab_bar = ui.colors.tab_bar,
			render = render_capsule_style,
		},
		-- Sharp retro powerline tabs with black/yellow/gray segmented arrows.
		powerline = {
			tab_bar = POWERLINE_TAB_BAR_COLORS,
			render = render_powerline_style,
		},
	}

	-- Uncomment exactly one style below.
	-- local selected_style = STYLES.capsule
	local selected_style = STYLES.powerline

	config.colors.tab_bar = selected_style.tab_bar

	wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, hover, max_width)
		return selected_style.render(tab, hover, max_width)
	end)
end
