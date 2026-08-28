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
-- Kitty keyboard protocol: OFF, which is also WezTerm's own default.
-- Claude Code enables it (since CC 2.1.0) for native Shift+Enter, but
-- WezTerm's CSI-u encoding of shifted keys violates the spec (wezterm#2546,
-- #3479: reports the SHIFTED codepoint where the spec wants the unshifted one,
-- and mis-maps non-US layouts). CC's decoder then drops shifted punctuation:
-- Shift+letter still uppercases, but Shift+1 / Shift+/ yield no ! and no ?.
-- The Ctrl/Shift+Enter bindings below do NOT need this on -- they SendString
-- the CSI-u bytes unconditionally, so nvim keeps working either way.
config.enable_kitty_keyboard = false

-- Send CSI-u sequences for Ctrl+Enter and Shift+Enter so nvim can
-- distinguish them from plain Enter.
config.keys = {
  { key = 'Enter', mods = 'CTRL',  action = wezterm.action.SendString '\x1b[13;5u' },
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString '\x1b[13;2u' },
}

return config
