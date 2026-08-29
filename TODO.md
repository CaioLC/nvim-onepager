# TODO

Setup is complete. Every dependency `init.lua` documents is installed and on PATH
(verified 2026-08-29): ripgrep, fd, tree-sitter CLI, clang, MSVC Build Tools,
lua-language-server, zls, wgsl-analyzer, lazygit. After a machine change, the
toolchain warning at the top of `init.lua` covers the parser build chain and
`:checkhealth` covers the rest.

## Open

- [ ] **Keymap and which-key structure** — worth doing in one pass rather than a
      mapping at a time:
  - `<leader>c` carries two meanings: `cb`/`cr`/`ct` are project runners, but the
    prefix reads as "code" generally. Pick one.
  - No which-key group labels for `<leader>t` (toggle) or `<leader>r` (config);
    `<leader>e`, `<leader>o`, `<leader>?` and `<leader>L` are unlabelled singles.
  - `<leader>L` (Lazy) and `<leader>rc` (open this config) are both "meta" —
    decide whether Lazy belongs under the same prefix.
  - `desc` strings follow no single convention ("Telescope find files" / "Jupyter:
    run # %% cell" / "code: run b" / "Open [R]C config"). They *are* the
    `<leader>fc` cheat-sheet, so a convention pays off twice.

## Known quirks — expected, not open bugs

- **pyrefly is per-env by design.** It is installed into project conda envs, not
  base, so Python gets an LSP only when nvim is launched from an env that has it.
  A FileType warning now says so rather than leaving the buffer silently
  server-less.
- **neopyter `table index is nil`** from `_on_bufwinenter` when a `*.ju.py` file
  resolves outside a running JupyterLab root. Upstream nil path in
  `jupyterlab.lua`; unaffected by how the plugin is loaded.

Molten's notes (the kill-kernel/wezterm-pane fix and the `exec_sync` return-value
bug behind it) were dropped when neopyter replaced it — see history up to `c177b8b`
if they are ever needed again.
