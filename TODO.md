# Setup TODO

Continuing from 2026-05-25 setup session. The toolchain swap (zig → clang + MSVC Build Tools) is done and tree-sitter parsers now compile. The remaining items are leftovers from `:checkhealth`.

## Required

- [ ] **wgsl-analyzer** — download, extract, put on PATH
  - URL: https://github.com/wgsl-analyzer/wgsl-analyzer/releases/download/2026-04-26/wgsl-analyzer-x86_64-pc-windows-msvc.zip
  - Suggested extract location: `%LOCALAPPDATA%\wgsl-analyzer\`
  - Add the bin dir to User PATH

## Optional (warnings only, nothing breaks)

- [ ] **fd** — extended telescope find-files capabilities
  - `winget install sharkdp.fd`
- [ ] **jsregexp** — luasnip variable/placeholder transformations (skip unless you use those snippet features)

## After everything is on PATH

- [ ] Restart **WezTerm** (not just nvim) so PATH propagates
- [ ] `:checkhealth` to confirm

(Molten's `:UpdateRemotePlugins` step is no longer manual — the `User LazyInstall/Update/Sync` autocmd in `init.lua` force-loads all plugins and regenerates the manifest on any `:Lazy sync`.)

## In progress — Molten kill-kernel should also close the wezterm image pane (2026-06-08)

`<leader>jK` (`molten_kill` in `init.lua`) kills the buffer's kernel via `:MoltenDeinit`
and then tries to close the wezterm split pane molten opens for image output. **The
kernel dies but the right-hand terminal pane stays open** — the close step isn't working.

Context already established:
- Molten's wezterm provider (`molten_image_provider = "wezterm"`) creates the split pane
  at `MoltenInit` time (rplugin `__init__.py:203` → `WeztermCanvas.wezterm_split`), in
  direction `molten_split_direction` (default `"right"`, not overridden in our config).
- `:MoltenDeinit` does NOT close that pane — molten only calls `canvas.deinit()`
  (`close_image_pane`) from `_deinitialize`, which runs on full nvim ExitPre, not on deinit.
- Our `molten_kill` attempt: `require('wezterm').exec_sync({'cli','get-pane-direction','Right'})`
  to find the pane, then `kill-pane --pane-id`. This is what's failing.

Things to try tomorrow:
- Verify what `wezterm.exec_sync({'cli','get-pane-direction','Right'})` actually returns
  (return-value shape may differ from the molten loader's usage; maybe it's not (ok, stdout)).
  Test live: `:lua print(vim.inspect(require('wezterm').exec_sync({'cli','get-pane-direction','Right'})))`
- Direction string case — confirm wezterm cli wants `Right` vs `right`.
- The molten loader (`lua/load_wezterm_nvim.lua`) closes the pane via `send-text` of a
  `wezterm cli kill-pane` command into the pane, NOT a direct `cli kill-pane` — maybe the
  direct form needs `--pane-id` as the molten-tracked id, which we don't have from Lua.
- More robust alternative: capture the image pane id ourselves right after `MoltenInit`
  (record `get-pane-direction` result into a global), then kill that exact id on deinit.
  Watch out: `MoltenInit` with a kernel picker is async, so capture must happen after the
  split actually exists.
- Possibly cleanest: check whether molten exposes the pane id, or file/patch upstream so
  `MoltenDeinit` closes the pane.

## Already done this session

- LLVM/clang installed, on User PATH
- VS 2022 Build Tools with VCTools workload + Windows 10 SDK 10.0.26100 installed (so clang finds `stdio.h` etc.)
- ripgrep installed
- lua-language-server installed
- pyrefly installed into base conda (on PATH)
- `nvim` conda env created at `%USERPROFILE%\.conda\envs\nvim` with `pynvim`, `jupyter_client`, `ipykernel`
- `init.lua` updated:
  - `vim.env.CC = 'clang'` (was `'zig cc'`)
  - `vim.g.python3_host_prog` now resolves `$USERPROFILE` at runtime (was hardcoded to another user's path)
  - Added `loaded_perl_provider`/`loaded_ruby_provider`/`loaded_node_provider = 0` to silence checkhealth
- `CLAUDE.md` updated to reflect the clang swap and dynamic python path
