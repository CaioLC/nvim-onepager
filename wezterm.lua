-- WezTerm config (version-controlled with the nvim repo).
--
-- WezTerm doesn't read this file directly — it looks at ~/.wezterm.lua.
-- On a new machine, create that file with this single line so it loads
-- the config from here:
--
--     return dofile(os.getenv('USERPROFILE') .. [[\AppData\Local\nvim\wezterm.lua]])
--
-- That 1-line shim is the only per-machine setup needed.

local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- OpenGL renderer: the WebGpu default causes rendering artifacts (stale
-- pixel fragments on typing/moving/resizing) on some Windows GPU drivers.
config.front_end = 'OpenGL'

config.default_prog = { 'powershell.exe', '-NoLogo' }
config.default_cwd = 'C:/projects'
config.color_scheme = 'Tokyo Night'
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }
config.scrollback_lines = 10000
config.enable_kitty_keyboard = true

-- Send CSI-u sequences for Ctrl+Enter and Shift+Enter so nvim can
-- distinguish them from plain Enter.
config.keys = {
  { key = 'Enter', mods = 'CTRL',  action = wezterm.action.SendString '\x1b[13;5u' },
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString '\x1b[13;2u' },
}

return config
