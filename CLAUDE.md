# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Neovim + WezTerm config kept deliberately as a **one-pager**: everything lives in `init.lua` and `wezterm.lua`. There is no `lua/` tree, no separate plugin-spec files, no module split. The design intent is that the entire config is auditable in two flat files. **When adding features, edit `init.lua` in place — do not introduce new files or a module tree.**

Platform: Windows (paths, `winget`, PowerShell, App Execution Aliases). The config is not portable to macOS/Linux without changes.

## How the files are wired on the host

- `init.lua` is loaded by Neovim from `%USERPROFILE%\AppData\Local\nvim\init.lua`. This repo is expected to live at (or be symlinked to) that location.
- `wezterm.lua` lives in this repo but WezTerm itself reads `~/.wezterm.lua`. The user creates a one-line shim there: `return dofile(os.getenv('USERPROFILE') .. [[\AppData\Local\nvim\wezterm.lua]])`. That shim is the only per-machine WezTerm setup.

## OS-level dependencies (not pip/npm — system binaries)

These are documented at the top of `init.lua`. They must be on PATH for the config to work:

- `ripgrep`, `fd` — telescope live-grep / find-files
- `tree-sitter` CLI — auto-installed via `winget` at startup if missing (init.lua:20-32); required because nvim-treesitter is pinned to the `main` branch, which compiles parsers from source
- `clang` (LLVM) — used as the C compiler for tree-sitter parser builds via `vim.env.CC = 'clang'` (init.lua:15). Avoids needing MSVC's `cl.exe`. Install via `winget install LLVM.LLVM`; PATH is set by the installer.
- `zls` — Zig LSP server, also manual install + PATH
- `conda env 'nvim'` with `pynvim`, `jupyterlab`, `neopyter`, `lckr_jupyterlab_variableinspector`, `itables` — hosts JupyterLab for the neopyter notebook workflow (`<leader>jl` launches it). Created at `%USERPROFILE%\.conda\envs\nvim` (via `conda create --prefix ...`). init.lua resolves `$USERPROFILE` at runtime, so this is portable across machines as long as the env lives in that conventional spot.

## Non-obvious architectural choices

1. **nvim-treesitter `main` branch, not `master`.** The plugin spec at init.lua:38-43 explicitly pins `branch = "main"`. The main branch has a different API: parsers are installed via `require('nvim-treesitter').install({...})` (init.lua:271) rather than the legacy `ensure_installed` table. Highlighting/folds/indent are enabled per-filetype via an autocmd at init.lua:275-282, not globally. **Do not "fix" this to look like a standard `master`-branch setup.**

2. **`vim.lsp.config` API (Neovim 0.11+).** LSP servers (luals, pyrefly, zls, wgsl-analyzer) are declared via `vim.lsp.config['name'] = {...}` then activated with `vim.lsp.enable({...})` at init.lua:223. This is the new native API, not `lspconfig.setup{}` — do not migrate it to `nvim-lspconfig` patterns.

3. **CSI-u keyboard encoding** is enabled in WezTerm (wezterm.lua:20-26) so nvim can distinguish `<C-CR>` and `<S-CR>` from plain `<CR>`. The neopyter cell-runner keymaps (Ctrl+Enter / Shift+Enter in `*.ju.py` buffers) depend on this. If you break the WezTerm `keys` block, those mappings silently stop working.

4. **Format-on-save autocmd** at init.lua:243-258 is attached to *every* LSP that advertises `textDocument/formatting`. It applies project-wide — there is no per-filetype opt-out. Adding a new LSP automatically opts it in.

5. **Tree-sitter install happens at top-level scope**, not inside a plugin `config` callback (init.lua:271). This runs on every `init.lua` load. The plugin itself handles deduplication.

6. **Notebooks run in the browser, not in nvim.** Python notebooks are `*.ju.py` files with `# %%` cells; neopyter (direct mode — nvim hosts an RPC server on 127.0.0.1:9001 via websocket.nvim) mirrors them into JupyterLab, where cells execute and outputs render. nvim must be running before JupyterLab starts. There is deliberately no in-editor output rendering — do not add molten-nvim/image.nvim-style inline outputs back.

## Useful commands inside Neovim

- `<leader>rc` — open this `init.lua`
- `<leader>L` or `:Lazy` — plugin manager UI
- `:Lazy sync` / `:Lazy update` — update plugins
- `:checkhealth` — diagnose provider / plugin / parser issues
- `:lua require('nvim-treesitter').install({'lang'})` — force-install or rebuild a single parser (use after fixing compiler errors)
- `<leader>jl` — launch JupyterLab (browser) from the `nvim` conda env; `:RegisterCondaKernels` — register conda envs (with ipykernel) as Jupyter kernels

## When something in tree-sitter breaks

The compile path is: nvim-treesitter (main branch) → `tree-sitter` CLI → Rust `cc` crate → `$CC` (clang) → produces `parser.so`. Common failure modes:

- `'cl.exe' ... program not found` → `$env:CC` not set or clang not on PATH. Check init.lua:15 and that `where.exe clang` resolves.
- `unknown command: -O2` (or similar from `zig`) → the previous `CC=zig cc` setup is back; the Rust `cc` crate doesn't split `CC` on whitespace reliably on Windows, so the `cc` subcommand gets dropped. Use a single-binary compiler like `clang` instead.
- `'tree-sitter' is not executable` → CLI not installed; the auto-installer at init.lua:20 should handle it but requires winget on PATH.
- `'winget' is not executable` (from `vim.fn.system`) → use the **string form** of `system()`, not the list form. winget is an App Execution Alias (reparse point) and nvim's list-form executable check rejects it. The init.lua auto-installer already uses the string form for this reason — preserve that.

## Git / commit conventions

Commit messages in this repo are short, lowercase, present-tense fragments (e.g. "format on save", "which-key and python repl"). Match that style.
