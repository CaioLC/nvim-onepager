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

## Done — Molten kill-kernel closes the wezterm image pane (2026-06-09, live-confirmed)

`<leader>jK` (`molten_kill` in `init.lua`) kills the buffer's kernel via `:MoltenDeinit`
AND closes the wezterm split pane molten opens for image output. Confirmed working.

Root cause of the earlier failure: `pcall(wez.exec_sync, {...})` captured `exec_sync`'s
first return value, which is its `(ok, stdout, stderr)` **boolean** `ok` — not the pane id —
so `tonumber(true)` was always `nil` and nothing got killed. Fix: drop the pcall and use
wezterm.nvim's `get_pane_direction(dir)`, which returns the trimmed neighbour pane id
directly; the pane is then killed with `exec_sync({'cli','kill-pane','--pane-id', id})`.
Direction comes from `molten_split_direction` (default `"right"`); the reference pane is
inferred from `$WEZTERM_PANE` (inherited by the subprocess), so no pane id is passed in
(passing a number would break `vim.system`, which wants string args). Committed in `c177b8b`.

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
