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

config.default_prog = { 'powershell.exe', '-NoLogo' }
-- Default cwd: the projects dir lives on a different drive per machine, so take
-- the first candidate that exists (glob of a literal path matches only itself).
-- If none exist, default_cwd stays unset and wezterm falls back to the home dir.
for _, dir in ipairs({ 'C:/projects', 'A:/projects' }) do
  if #wezterm.glob(dir) > 0 then
    config.default_cwd = dir
    break
  end
end
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
