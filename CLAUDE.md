# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Neovim + WezTerm config kept deliberately as a **one-pager**: everything lives in `init.lua` and `wezterm.lua`. There is no `lua/` tree, no separate plugin-spec files, no module split. The design intent is that the entire config is auditable in two flat files. **When adding features, edit `init.lua` in place — do not introduce new files or a module tree.**

Platform: Windows (paths, `winget`, PowerShell, App Execution Aliases). The config is not portable to macOS/Linux without changes.

## How the files are wired on the host

- Both configs are loaded through one-line `dofile` shims that point at **this repo's checkout** (e.g. `A:\projects\nvim-onepager`). Nothing but the shims lives outside the repo.
- Neovim reads `%USERPROFILE%\AppData\Local\nvim\init.lua`; on this host that file is the shim: `return dofile([[A:\Projects\nvim-onepager\init.lua]])`. That dir is *not* a checkout of this repo — it only holds the shim plus lazy.nvim's `lazy-lock.json` (gitignored, written to `stdpath('config')`).
- WezTerm reads `~/.wezterm.lua`, which is the matching shim: `return dofile([[A:\Projects\nvim-onepager\wezterm.lua]])`.
- **Point shims at the repo, never at `%USERPROFILE%\AppData\Local\nvim\`.** A copy of `wezterm.lua` left in that dir silently wins over the repo and is never updated by `git pull` — that exact stale copy (with `enable_kitty_keyboard = true`) was removed 2026-08-29.
- Because `$MYVIMRC` is the shim, code that needs the real file's path uses the running chunk's own source (`debug.getinfo(1, 'S').source`) — see `<leader>rc`, the `lazygit.yml` lookup, and the command-palette scanner.

## OS-level dependencies (not pip/npm — system binaries)

These are documented at the top of `init.lua`. They must be on PATH for the config to work:

- `ripgrep`, `fd` — telescope live-grep / find-files
- `tree-sitter` CLI — required because nvim-treesitter is pinned to the `main` branch, which compiles parsers from source. **Not** auto-installed: the startup check (`local fixes`, init.lua:84) only *warns*, printing a paste-able PowerShell command per missing dep. Auto-installing was dropped because LLVM and the Build Tools install machine-wide (UAC) and their PATH changes need a terminal restart anyway.
- `clang` (LLVM) — used as the C compiler for tree-sitter parser builds via `vim.env.CC = 'clang'` (init.lua:74). Avoids needing MSVC's `cl.exe`. Install via `winget install LLVM.LLVM`; the startup warning pairs the install with a User-scope PATH append, because the LLVM package does not add itself to PATH.
- MSVC Build Tools (VCTools workload) — supplies the Windows SDK headers clang targets. Probed by globbing for a real `ucrt/stdio.h`, not by running vswhere.
- `zls` — Zig LSP server, also manual install + PATH
- `conda env 'nvim'` with `pynvim`, `jupyterlab`, `neopyter`, `lckr_jupyterlab_variableinspector`, `itables` — hosts JupyterLab for the neopyter notebook workflow (`<leader>jl` launches it). Created at `%USERPROFILE%\.conda\envs\nvim` (via `conda create --prefix ...`). init.lua resolves `$USERPROFILE` at runtime, so this is portable across machines as long as the env lives in that conventional spot.

## Non-obvious architectural choices

1. **nvim-treesitter `main` branch, not `master`.** The plugin spec (init.lua:146) explicitly pins `branch = "main"`. The main branch has a different API: parsers are installed via `require('nvim-treesitter').install({...})` rather than the legacy `ensure_installed` table. **Do not "fix" this to look like a standard `master`-branch setup.** One list, `ts_filetypes` (init.lua:958), feeds both the install call and the `FileType` autocmd pattern that starts highlighting/folds/indent — keep it that way, since two lists silently drift into parsers that are compiled every startup and never used. `markdown_inline` is passed to `install` only: it is injected into markdown buffers, it is not a filetype.

2. **`vim.lsp.config` API (Neovim 0.12 here, 0.11+ generally).** LSP servers are declared via `vim.lsp.config['name'] = {...}`, listed once in `servers` and activated with `vim.lsp.enable(servers)` (init.lua:684). This is the new native API, not `lspconfig.setup{}` — do not migrate it to `nvim-lspconfig` patterns. A `vim.lsp.config['*']` block (init.lua:634) merges into every server; it sets `snippetSupport = false` on purpose (see 7).

3. **A missing LSP binary is warned about at `FileType`, not at startup** (init.lua:684 onward). `pyrefly` lives in each project's conda env, so whether it resolves depends on the env nvim was launched from; a startup check would report on the wrong environment. nvim skips an unresolvable `cmd` silently, which is why the warning exists at all.

4. **Modified-key encoding is hand-rolled, not protocol-wide.** The kitty keyboard protocol is **off** (`config.enable_kitty_keyboard = false`, wezterm.lua:43) — WezTerm's CSI-u encoding of shifted keys is out of spec (wezterm#2546, #3479) and eats shifted punctuation in other TUIs sharing the terminal. Instead the `keys` block (wezterm.lua:47) `SendString`s the CSI-u bytes for exactly two keys, Ctrl+Enter and Shift+Enter (`\x1b[13;5u` / `\x1b[13;2u`), which nvim decodes as `<C-CR>`/`<S-CR>`. The neopyter cell-runner keymaps depend on that block — break it and they silently stop working. **Corollary:** every *other* Ctrl+punctuation key arrives in legacy form, so Ctrl+/ reaches nvim as `<C-_>`, not `<C-/>`; init.lua binds both spellings. Don't add a mapping for a `<C-punct>` key without checking which form the terminal actually sends.

5. **Format-on-save** (init.lua:859) is attached to *every* LSP that advertises `textDocument/formatting`. It applies project-wide — there is no per-filetype opt-out. Adding a new LSP automatically opts it in. The `BufWritePre` hook is registered **idempotently** (clear-then-add within `LspFormatOnSave`): `LspAttach` fires once per client *and again on every buffer reload*, so a naive registration stacks hooks and a re-`:e`'d buffer formats itself several times per save. Keep the clear.

6. **Tree-sitter install happens at top-level scope**, not inside a plugin `config` callback (init.lua:959). This runs on every `init.lua` load. The plugin itself handles deduplication.

7. **Completion is nvim-cmp with LSP + path sources only, and no snippets.** `snippetSupport = false` (init.lua:636) is deliberate: with it on, servers return function completions as snippets like `fn(${1:a}, ${2:b})`, which expand into placeholders you tab between. Instead the parameter list is shown by an automatic signature float driven off the server's own trigger characters (init.lua:732) — nvim has an autotrigger for completion but none for signature help, so it is wired by hand. The native `vim.lsp.completion` autotrigger is deliberately **not** enabled: two engines racing for one popup. There is no buffer-word source and no snippet plugin (`vim.snippet` is the fallback expander). Do not "restore" LuaSnip/cmp-buffer or turn snippetSupport back on.

8. **Notebooks run in the browser, not in nvim.** Python notebooks are `*.ju.py` files with `# %%` cells; neopyter (direct mode — nvim hosts an RPC server on 127.0.0.1:9001 via websocket.nvim) mirrors them into JupyterLab, where cells execute and outputs render. nvim must be running before JupyterLab starts. There is deliberately no in-editor output rendering — do not add molten-nvim/image.nvim-style inline outputs back. The plugin is lazy-loaded on `BufReadPre/BufNewFile *.ju.py` (init.lua:307) — lazy.nvim splits an `"<Event> <pattern>"` spec — so its attach autocmds still exist before the buffer is read.

9. **Startup is eager on purpose for navigation.** tokyonight, treesitter, telescope and oil load at startup so navigation is instant; everything else (cmp on `InsertEnter`, neopyter on a `.ju.py` buffer, which-key on `VeryLazy`, aerial/render-markdown on keys/ft) is lazy. Don't make oil/telescope lazy to shave startup ms — that trade was considered and rejected.

## Useful commands inside Neovim

- `<leader>rc` — open this `init.lua`
- `<leader>L` or `:Lazy` — plugin manager UI
- `:Lazy sync` / `:Lazy update` — update plugins
- `:checkhealth` — diagnose provider / plugin / parser issues
- `:lua require('nvim-treesitter').install({'lang'})` — force-install or rebuild a single parser (use after fixing compiler errors)
- `<leader>fc` — fuzzy-search this config's own mappings and commands (built live from `desc` fields)
- `<leader>gg` — lazygit in a floating terminal, themed by the repo's `lazygit.yml`
- `<leader>jl` — launch JupyterLab (browser) from the `nvim` conda env; `:RegisterCondaKernels` — register conda envs (with ipykernel) as Jupyter kernels

## When something in tree-sitter breaks

The compile path is: nvim-treesitter (main branch) → `tree-sitter` CLI → Rust `cc` crate → `$CC` (clang) → produces `parser.so`. Common failure modes:

- `'cl.exe' ... program not found` → `$env:CC` not set or clang not on PATH. Check init.lua:15 and that `where.exe clang` resolves.
- `unknown command: -O2` (or similar from `zig`) → the previous `CC=zig cc` setup is back; the Rust `cc` crate doesn't split `CC` on whitespace reliably on Windows, so the `cc` subcommand gets dropped. Use a single-binary compiler like `clang` instead.
- `'tree-sitter' is not executable` → CLI not installed; the auto-installer at init.lua:20 should handle it but requires winget on PATH.
- `'winget' is not executable` (from `vim.fn.system`) → winget is an App Execution Alias (reparse point), and nvim's list-form executable check rejects it; use the **string form** of `system()`. init.lua no longer shells out to winget at all (the startup check only prints commands for you to paste), but keep this in mind before adding any winget call back.

## Git / commit conventions

Commit messages in this repo are short, lowercase, present-tense fragments (e.g. "format on save", "which-key and python repl"). Match that style.
