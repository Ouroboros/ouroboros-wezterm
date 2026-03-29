local wezterm = require("wezterm")

local config = wezterm.config_builder()

require("config.startup")(wezterm, config)
require("config.appearance")(wezterm, config)
require("config.sessions")(wezterm, config)
require("config.status")(wezterm, config)
require("config.tabs")(wezterm, config)
require("config.keybings")(wezterm, config)

return config
