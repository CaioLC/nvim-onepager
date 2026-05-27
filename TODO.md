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
