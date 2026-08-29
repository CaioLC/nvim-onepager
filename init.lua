-- =============================================================================
-- OS dependencies (Windows; install manually unless marked auto-installed).
-- Single source of truth for what a fresh machine needs before this config runs.
-- =============================================================================
--
-- Terminal emulator (<leader>wt / <leader>c runners / <leader>jl native panes)
--   wezterm                -> winget install wez.wezterm
--                             (optional — the pane helpers fall back to nvim
--                              :terminal when not in a wezterm session)
--
-- Git UI (floating panel via <leader>gg; themed by repo-local lazygit.yml)
--   lazygit                -> winget install JesseDuffield.lazygit
--                             The <leader>gg panel passes lazygit.yml explicitly,
--                             so the in-nvim theme needs no per-machine setup.
--                             For standalone `lazygit` in a shell, symlink this
--                             repo's lazygit.yml onto lazygit's default config path
--                             (path: `lazygit --print-config-dir`).
--                             Linux:
--                               ln -sf <repo>/lazygit.yml ~/.config/lazygit/config.yml
--                             Windows (default dir %LOCALAPPDATA%\lazygit): Developer
--                             Mode allows symlinks without admin, but PS 5.1's
--                             New-Item does not pass the unprivileged flag -- use
--                             Python 3.8+ (os.symlink does) or pwsh 7+:
--                               python -c "import os;os.symlink(r'<repo>\lazygit.yml',os.path.expandvars(r'%LOCALAPPDATA%\lazygit\config.yml'))"
--
-- Tree-sitter parser build chain (checked at startup; nvim warns if any are missing)
--   LLVM (clang)           -> winget install LLVM.LLVM
--   MSVC Build Tools       -> winget install Microsoft.VisualStudio.2022.BuildTools
--                             --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
--                             (the VCTools workload pulls the MSVC toolset + Windows
--                              SDK headers/libs clang needs for the msvc target)
--   tree-sitter CLI        -> winget install tree-sitter.tree-sitter-cli
--
-- Telescope backends
--   ripgrep                -> winget install BurntSushi.ripgrep.MSVC
--   fd                     -> winget install sharkdp.fd
--
-- LSP servers (must be on PATH)
--   lua-language-server    -> winget install LuaLS.lua-language-server
--   pyrefly                -> pip install pyrefly  (any env that's on PATH)
--   zls                    -> manual: https://github.com/zigtools/zls/releases
--   wgsl-analyzer          -> manual: https://github.com/wgsl-analyzer/wgsl-analyzer/releases
--
-- Python provider + JupyterLab (for neopyter — cells run in a browser tab)
--   conda env 'nvim' at %USERPROFILE%\.conda\envs\nvim
--     packages: pynvim, jupyterlab, neopyter,
--               lckr_jupyterlab_variableinspector (live variable/dataframe panel),
--               itables (sortable/filterable dataframe tables; enable per notebook:
--               `from itables import init_notebook_mode; init_notebook_mode()`)
--   each conda env you want as a Jupyter kernel needs `ipykernel` installed;
--     register them in bulk via :RegisterCondaKernels (defined later)
--   one-time browser setup: in JupyterLab, open the Neopyter side panel and set
--     mode=direct, IP 127.0.0.1, port 9001 (persisted in browser localStorage)
-- =============================================================================

-- PYTHON PROVIDER
-- Resolves to %USERPROFILE%\.conda\envs\nvim\python.exe at runtime, so the path
-- is portable across machines as long as the env lives in that conventional spot.
-- Doubles as the interpreter <leader>jl launches JupyterLab from.
vim.g.python3_host_prog = vim.fn.expand('$USERPROFILE') .. '/.conda/envs/nvim/python.exe'

-- Disable unused language providers to silence checkhealth warnings.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

-- Disable built-in netrw so oil.nvim can hijack directory buffers (BufReadCmd).
-- Must be set before plugins load.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Use clang as the C compiler for tree-sitter parser builds (avoids needing MSVC cl.exe).
-- Single-binary invocation sidesteps the CC-splitting issue Windows had with `zig cc`.
vim.env.CC = 'clang'

-- CHECK PARSER BUILD TOOLCHAIN (warn only). Without clang ($CC), the MSVC/Windows
-- SDK headers clang targets, and the tree-sitter CLI, no parser compiles. We only
-- warn rather than auto-install: LLVM and the Build Tools install machine-wide
-- (admin/UAC) and add PATH entries that only take effect after a restart, so a
-- blocking startup install is a worse experience than a copy/paste fix. Each entry
-- below is a full PowerShell command the user can paste to fix that dep. All checks
-- are cheap and spawn no processes -- executable() is a PATH scan and glob is an
-- in-process directory read (we probe for a real SDK header, not vswhere).
local fixes = {}
if vim.fn.executable('clang') == 0 then
  -- The LLVM winget package installs clang but does NOT add it to PATH, so pair the
  -- (idempotent) install with a User-scope PATH append -- no admin needed. Long
  -- bracket string so the PowerShell quotes/backslashes need no Lua escaping.
  fixes[#fixes + 1] = [==[winget install LLVM.LLVM; $p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -notlike '*LLVM\bin*'){[Environment]::SetEnvironmentVariable('Path',$p+';C:\Program Files\LLVM\bin','User')}]==]
end
-- Probe for a real SDK header (glob a version dir), not just the Include folder:
-- the folder can exist empty, or appear mid-install, before headers are usable.
local sdk = vim.fs.joinpath(vim.env['ProgramFiles(x86)'] or 'C:\\Program Files (x86)',
  'Windows Kits', '10', 'Include', '*', 'ucrt', 'stdio.h')
if vim.fn.glob(sdk) == '' then
  fixes[#fixes + 1] = 'winget install Microsoft.VisualStudio.2022.BuildTools '
    .. '--override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
end
if vim.fn.executable('tree-sitter') == 0 then
  fixes[#fixes + 1] = 'winget install tree-sitter.tree-sitter-cli'
end
if #fixes > 0 then
  vim.schedule(function()
    vim.notify('Parser build toolchain incomplete -- tree-sitter parsers will not '
      .. 'compile. Paste in PowerShell, then restart your terminal and nvim:\n\n'
      .. table.concat(fixes, '\n\n'), vim.log.levels.WARN)
  end)
end

-- Set leaders BEFORE lazy.setup so plugin specs using `keys = { '<leader>...' }`
-- resolve `<leader>` to space (not the default `\`) at spec-evaluation time.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- SETUP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- PLUGINS
require("lazy").setup({
  spec = {
    {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        vim.cmd([[colorscheme tokyonight]])
      end,
    },

    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main",
      lazy = false,
      build = ":TSUpdate",
    },

    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp", -- LSP completion source
        "hrsh7th/cmp-buffer",   -- Buffer words completion
        "hrsh7th/cmp-path",     -- File path completion
        "L3MON4D3/LuaSnip",     -- Snippet engine (optional but recommended)
      },
      config = function()
        local cmp = require("cmp")
        cmp.setup({
          snippet = {
            expand = function(args)
              -- For LuaSnip (optional)
              require("luasnip").lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-b>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item
            ["<Tab>"] = cmp.mapping.select_next_item(),
            ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" }, -- LSP completions
            { name = "buffer" },   -- Current buffer words
            { name = "path" },     -- File system paths
          }),
          -- Better completion experience
          completion = {
            completeopt = "menu,menuone,noinsert,noselect",
          },
        })
      end,
    },

    {
      -- Auto-close (), [], {}, quotes, backticks. Treesitter-aware (check_ts), so it
      -- won't pair inside strings/comments. Per-language config lives in this block:
      --   • disable_filetype — turn autopairs OFF entirely for a filetype
      --   • per_ft_rules      — add extra pairs scoped to specific filetypes
      -- The built-in pairs already apply to every language; edit the tables to tune.
      'windwp/nvim-autopairs',
      event = 'InsertEnter',
      dependencies = { 'hrsh7th/nvim-cmp', 'nvim-treesitter/nvim-treesitter' },
      config = function()
        local npairs = require('nvim-autopairs')
        local Rule = require('nvim-autopairs.rule')

        npairs.setup({
          check_ts = true,                          -- skip pairing inside strings/comments
          disable_filetype = { 'TelescopePrompt' }, -- filetypes with autopairs OFF
        })

        -- Language-specific extra pairs. Rule(open, close, filetypes) scopes a pair to
        -- the listed filetypes only. Add entries here to configure pairs per language,
        -- e.g. angle brackets for generics/tags (commented out — uncomment to enable):
        local per_ft_rules = {
          -- { open = '<', close = '>', ft = { 'rust', 'zig', 'html', 'superhtml' } },
        }
        for _, r in ipairs(per_ft_rules) do
          npairs.add_rule(Rule(r.open, r.close, r.ft))
        end

        -- nvim-cmp integration: insert () after accepting a function/method completion.
        local ok, cmp = pcall(require, 'cmp')
        if ok then
          cmp.event:on('confirm_done', require('nvim-autopairs.completion.cmp').on_confirm_done())
        end
      end,
    },

    {
      'nvim-telescope/telescope.nvim',
      lazy = false, -- always used; load at startup
      dependencies = { 'nvim-lua/plenary.nvim' }
    },

    {
      'stevearc/oil.nvim',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      lazy = false, -- needs to load before BufReadCmd fires on directory args
      opts = {
        view_options = { show_hidden = true },
      },
    },

    {
      'nvim-lualine/lualine.nvim',
      dependencies = { 'nvim-tree/nvim-web-devicons' }
    },

    {
      'folke/which-key.nvim',
      event = "VeryLazy",
      opts = {
        preset = "helix",
        spec = {
          { "<leader>f", group = "find" },
          { "<leader>g", group = "git" },
          { "<leader>j", group = "jupyter" },
          { "<leader>w", group = "window" },
          { "<leader>c", group = "code" },
        },
      },
      keys = {
        {
          "<leader>?",
          function()
            require("which-key").show({ global = false })
          end,
          desc = "buffer Local Keymaps (which-key)",
        }
      }
    },

    {
      'stevearc/aerial.nvim',
      dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-tree/nvim-web-devicons',
      },
      keys = {
        { '<leader>o', '<cmd>AerialToggle!<CR>', desc = 'Toggle symbols outline' },
      },
      opts = {
        backends = { 'lsp', 'treesitter', 'markdown', 'man' },
        layout = {
          default_direction = 'right',
          placement = 'edge',
          min_width = 30,
        },
        -- Symbol kinds shown in the outline. Defaults omit Constant/Variable;
        -- include Constant explicitly so module-level constants surface.
        filter_kind = {
          'Class', 'Constructor', 'Constant', 'Enum', 'Function',
          'Interface', 'Method', 'Module', 'Struct',
        },
        show_guides = true,
        autojump = true,
      },
    },

    {
      -- Edit `*.ju.py` percent-format (# %%) files in nvim; neopyter mirrors the
      -- buffer into a notebook inside JupyterLab in the browser, where cells run
      -- and ALL outputs render (plots, itables dataframes, the variable-inspector
      -- panel) — nothing displays inside nvim. Direct mode: nvim hosts an RPC
      -- server (websocket.nvim) on remote_address; the neopyter JupyterLab
      -- extension (pip package in the 'nvim' conda env) connects to it. Start
      -- nvim first, then JupyterLab (<leader>jl). Cell keymaps live in the
      -- JUPYTER section below, gated to *.ju.py buffers.
      "SUSTech-data/neopyter",
      dependencies = { "AbaoFromCUG/websocket.nvim" }, -- server impl for direct mode
      lazy = false, -- its attach autocmds must exist before a *.ju.py buffer opens
      opts = {
        mode = "direct",
        remote_address = "127.0.0.1:9001",
        file_pattern = { "*.ju.*" },
        highlight = { enable = true }, -- shade # %% separators (uses ts python parser)
      },
    },

    {
      -- In-buffer markdown rendering (headings, lists, code blocks, tables) via
      -- virtual text + concealment. Pure Lua, no browser/node. Relies on the
      -- markdown + markdown_inline treesitter parsers installed below.
      'MeanderingProgrammer/render-markdown.nvim',
      dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
      ft = { 'markdown' },
      -- Inline `code` spans: render with orange text on no background instead of
      -- the default blue-on-blue box. (Terminals can't size individual cells, so
      -- there's no "smaller font" option.)
      opts = {
        code = { highlight_inline = 'RenderMarkdownCodeInline' },
      },
      keys = {
        { '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', desc = 'Toggle markdown render' },
      },
    }
  },
  -- configure any other settings here. see documentation for detailes.
  -- automatically check for plugin updates
  checker = { enabled = true },
})

-- CONFIGS
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.o.termguicolors = true
vim.o.linebreak = true -- wrap at word boundaries, not mid-word
-- Share the unnamed register with the Windows clipboard, so plain y/d/p talk
-- to other apps without the "+ prefix. The provider is win32yank.exe, which
-- ships with the Neovim Windows installer -- nothing to install.
vim.o.clipboard = 'unnamedplus'
require('lualine').setup({
  sections = {
    lualine_b = { 'branch', 'diagnostics' },
    lualine_c = {
      {
        'filename',
        path = 1,           -- relative path (keeps symbols/modified flags)
        fmt = function(str) -- trim to file + 2 parent dirs, never above root
          if not str or str == '' then return str end
          local parts = vim.split(str:gsub('\\', '/'), '/', { trimempty = true })
          local n = #parts
          return table.concat({ unpack(parts, math.max(1, n - 2), n) }, '/')
        end,
      },
    },
    lualine_x = { 'filetype' },
    lualine_y = { 'lsp_status' },
  }
})

-- KEYMAPS | Keybindings
vim.keymap.set('n', '<leader>rc', ':e $MYVIMRC<CR>', { desc = 'Open [R]C config' }) -- Open init.lua
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'Lazy.nvim UI' })            -- Open Lazy
-- <Cmd> (not ':...<CR>') so it runs without entering command-line mode and without
-- swallowing a pending count/operator — plain <Esc>'s normal-mode cancel still works.
vim.keymap.set('n', '<Esc>', '<Cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>') -- space with no following letter has no effect on normal and visual mode
-- With wrap on, move by screen line so j/k step through wrapped rows one at a time.
-- The v:count guard keeps {count}j/k (and relativenumber jumps like 5k) on real lines.
vim.keymap.set({ 'n', 'v' }, 'j', "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true, desc = 'Down by screen line' })
vim.keymap.set({ 'n', 'v' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Up by screen line' })
-- window
vim.keymap.set('n', '<leader>ws', '<C-w>s', { desc = 'Split window horizontal' })
vim.keymap.set('n', '<leader>wv', '<C-w>v', { desc = 'Split window vertical' })
vim.keymap.set('n', '<leader>wq', '<C-w>q', { desc = 'Close current window' })
vim.keymap.set('n', '<leader>wo', '<C-w>o', { desc = 'Close other windows' })
vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = 'Equalize window sizes' })
vim.keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Focus window left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Focus window below' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Focus window above' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Focus window right' })
vim.keymap.set('n', '<leader>wt', function()
  -- Inside wezterm: split the host pane (native, no nested terminal emulator).
  -- Elsewhere: fall back to nvim's built-in :terminal in a split below.
  if vim.env.WEZTERM_PANE then
    vim.fn.jobstart({ 'wezterm', 'cli', 'split-pane', '--bottom' }, { detach = true })
  else
    vim.cmd('belowright split | terminal')
  end
end, { desc = 'Open terminal pane below' })
vim.keymap.set('t', '<Esc>', '<C-\\><C-N>', { desc = 'Normal Mode in terminal' })
vim.keymap.set('t', '<C-w>', "<C-\\><C-n><C-w>")
vim.keymap.set('n', '<C-g>', "3<C-w>_", { desc = 'Maximize current window' })
-- comment toggle (Ctrl+/ needs CSI-u in wezterm to be distinct from <CR>/<BS>)
vim.keymap.set('n', '<C-/>', 'gcc', { remap = true, desc = 'Toggle comment line' })
vim.keymap.set('x', '<C-/>', 'gc', { remap = true, desc = 'Toggle comment selection' })

-- Language-aware <leader>c (code) runners. A project type is recognised by a
-- root marker found upward from the cwd; the shared subcommand letters then run
-- that language's command. The same letter means different things per language
-- (cb = `zig build` in a zig project), resolved at keypress time. Add a language
-- by adding a table here — no other wiring needed.
local code_runners = {
  zig = {
    root = { 'build.zig', 'build.zig.zon' },
    cmds = {
      b = { cmd = 'zig build', desc = 'zig build' },
      r = { cmd = 'zig build run', desc = 'zig build run' },
      t = { cmd = 'zig build test', desc = 'zig build test' },
    },
  },
}

-- Run a shell command in a bottom pane: a native wezterm split when hosted in
-- wezterm (mirrors <leader>wt), otherwise an nvim :terminal split. Either way
-- the output stays open to read. cwd is the resolved project root.
local function run_in_pane(cmd, cwd)
  if vim.env.WEZTERM_PANE then
    vim.fn.jobstart({ 'wezterm', 'cli', 'split-pane', '--bottom', '--cwd', cwd,
      '--', 'powershell.exe', '-NoLogo', '-NoExit', '-Command', cmd }, { detach = true })
  else
    vim.cmd('botright split | lcd ' .. vim.fn.fnameescape(cwd) .. ' | terminal ' .. cmd)
  end
end

-- Bind every subcommand letter used by any runner once. The handler resolves the
-- current project from cwd at keypress time and runs that language's command.
local code_keys = {}
for _, spec in pairs(code_runners) do
  for key in pairs(spec.cmds) do code_keys[key] = true end
end
for key in pairs(code_keys) do
  vim.keymap.set('n', '<leader>c' .. key, function()
    local cwd = vim.fn.getcwd()
    for _, spec in pairs(code_runners) do
      local root = vim.fs.root(cwd, spec.root)
      local entry = root and spec.cmds[key]
      if entry then
        vim.cmd('silent! wall') -- write all buffers before building/running
        run_in_pane(entry.cmd, root)
        return
      end
    end
    vim.notify('No <leader>c' .. key .. ' runner for this project (' .. cwd .. ')',
      vim.log.levels.WARN)
  end, { desc = 'code: run ' .. key })
end

-- file explorer
vim.keymap.set('n', '<leader>e', '<Cmd>Oil<CR>', { desc = 'Open file explorer (oil)' })

-- lazygit in a centered floating terminal. Auto-closes when lazygit exits;
-- :checktime reloads any buffers whose on-disk file lazygit changed (stash,
-- checkout, commit-amend, etc.) so nvim doesn't show a stale view.
vim.keymap.set('n', '<leader>gg', function()
  if vim.fn.executable('lazygit') == 0 then
    vim.notify('lazygit not on PATH. Install: winget install JesseDuffield.lazygit',
      vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })
  -- The global t-mode <Esc> map (-> <C-\><C-N>) would drop us to normal mode in
  -- this terminal instead of reaching lazygit, which uses <Esc> as its own
  -- back/cancel key. Override it buffer-locally so <Esc> passes through to lazygit.
  vim.keymap.set('t', '<Esc>', '<Esc>', { buffer = buf, desc = 'Pass <Esc> to lazygit' })
  -- Use the repo-local lazygit.yml (tokyonight theme) so the accent matches nvim
  -- without any per-machine lazygit config-dir setup. Locate it next to THIS file
  -- via the running chunk's own source path, not $MYVIMRC: when nvim's config dir
  -- is a one-line `dofile` shim (the Windows setup) rather than a symlink into the
  -- repo, $MYVIMRC is the shim and lazygit.yml isn't beside it. The chunk source
  -- is always this actual file; fs_realpath additionally follows a symlinked
  -- config dir into the repo (the Linux setup). A bad --use-config-file path makes
  -- lazygit error out and close instantly, so only pass it when it exists.
  local cmd = { 'lazygit' }
  local this = debug.getinfo(1, 'S').source:sub(2)
  local lazygit_config = vim.fs.joinpath(
    vim.fs.dirname(vim.uv.fs_realpath(this) or this), 'lazygit.yml')
  if vim.uv.fs_stat(lazygit_config) then
    vim.list_extend(cmd, { '--use-config-file', lazygit_config })
  end
  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      vim.cmd('checktime')
    end,
  })
  vim.cmd('startinsert')
end, { desc = 'Lazygit (floating)' })

-- telescope
local t_builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', t_builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', t_builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', t_builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', t_builtin.help_tags, { desc = 'Telescope help tags' })

-- <leader>fc: searchable cheat-sheet of THIS config's own actions, so you can find a
-- mapping you forgot by fuzzy-searching its description ("jupyter", "window", ...).
-- Built live from the leader keymaps (global + current buffer) and user commands, so
-- it never drifts from init.lua -- give a mapping a `desc` and it shows up here for
-- free. <CR> runs a normal-mode map; for a command it drops ':Cmd ' onto the cmdline
-- so you review before executing; visual-mode maps just close.
local function find_custom_functions()
  local pickers      = require('telescope.pickers')
  local finders      = require('telescope.finders')
  local conf         = require('telescope.config').values
  local actions      = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local items, seen = {}, {}
  local function harvest(maps)
    for _, m in ipairs(maps) do
      -- Leader is <Space>, so nvim stores these lhs with a leading space; a non-empty
      -- desc is what every mapping in this config carries -- together that's "mine".
      if m.desc and m.desc ~= '' and m.lhs:sub(1, 1) == ' ' and not seen[m.mode .. m.lhs] then
        seen[m.mode .. m.lhs] = true
        local keys = m.lhs
        items[#items + 1] = {
          sort    = '1' .. m.lhs,
          display = string.format('[%s] %-22s %s', m.mode, '<leader>' .. m.lhs:sub(2), m.desc),
          exec    = m.mode == 'n' and function()
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes(keys, true, false, true), 'm', false)
          end or nil,
        }
      end
    end
  end
  for _, mode in ipairs({ 'n', 'v' }) do
    harvest(vim.api.nvim_get_keymap(mode))
    harvest(vim.api.nvim_buf_get_keymap(0, mode))
  end
  -- Commands need a stricter filter: nvim_get_commands() also returns nvim's built-ins
  -- (:Inspect, :Open, ...) and every plugin command (:Lazy, :Telescope, ...), none of
  -- which are "mine". The source of truth for my commands is this one-pager itself, so
  -- scan it for nvim_create_user_command names and keep only those. debug.getinfo gives
  -- the real file even behind the dofile shim ($MYVIMRC would be the shim).
  local mine = {}
  local path = debug.getinfo(1, 'S').source:sub(2)
  local f = io.open(vim.uv.fs_realpath(path) or path, 'r')
  if f then
    for line in f:lines() do
      local name = line:match("nvim_create_user_command%(%s*['\"]([%w_]+)")
      if name then mine[name] = true end
    end
    f:close()
  end
  for name, cmd in pairs(vim.api.nvim_get_commands({})) do
    if mine[name] then
      items[#items + 1] = {
        sort    = '2' .. name,
        display = string.format('[:] %-22s %s', name, cmd.definition or ''),
        exec    = function() vim.api.nvim_feedkeys(':' .. name .. ' ', 'n', false) end,
      }
    end
  end
  table.sort(items, function(a, b) return a.sort < b.sort end)

  pickers.new({}, {
    prompt_title = 'Custom functions (init.lua)',
    finder = finders.new_table({
      results = items,
      entry_maker = function(it)
        return { value = it, display = it.display, ordinal = it.display }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if entry and entry.value.exec then vim.schedule(entry.value.exec) end
      end)
      return true
    end,
  }):find()
end
vim.keymap.set('n', '<leader>fc', find_custom_functions,
  { desc = 'Find custom functions (init.lua)' })


-- LSP
vim.lsp.config['luals'] = {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      -- Teach luals about the `vim` global and the Neovim runtime files so
      -- `vim.api.*`, `vim.uv.*`, etc. resolve instead of warning as undefined.
      diagnostics = { globals = { 'vim' } },
      workspace = {
        library = vim.api.nvim_get_runtime_file('', true),
        checkThirdParty = false,
      },
    }
  }
}

vim.lsp.config['pyrefly'] = {
  cmd = { 'pyrefly', 'lsp' },
  filetypes = { 'python' },
  root_markers = { '.git', 'pyproject.toml', 'setup.py', 'requirements.txt' },
  settings = {
  },
  on_exit = function(code, _, _)
    vim.notify("Closing Pyrefly LSP exited with code: " .. code, vim.log.levels.INFO)
  end,
}

vim.lsp.config['zls'] = {
  cmd = { 'zls' },
  filetypes = { 'zig', 'zon' },
  root_markers = { '.git', 'build.zig', 'build.zig.zon' },
  settings = {
    zls = {
      enable_build_on_save = true,
    }
  }
}

vim.lsp.config['wgsl-analyzer'] = {
  cmd = { 'wgsl-analyzer' },
  filetypes = { 'wgsl' },
}
vim.lsp.enable({ 'luals', 'pyrefly', 'zls', 'wgsl-analyzer' })

-- pyrefly resolves via PATH from your active conda env. If it's missing and you're
-- doing Python work, install it into the activated env: pip install pyrefly
-- if vim.fn.executable('pyrefly') == 0 then
--   vim.notify('pyrefly not found. If working with Python, install it in your '
--     .. 'activated conda env: pip install pyrefly', vim.log.levels.WARN)
-- end
-- activate completion
-- Use CTRL-Y to select an item. |complete_CTRL-Y|
vim.opt.completeopt = 'menuone,noselect,popup'
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Autocomplete as you type (native 0.11 API). Pops on the server's trigger
    -- chars (e.g. '.') and filters as you keep typing; <C-x><C-o> still works.
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, args.data.client_id, bufnr, { autotrigger = true })
    end

    -- Help with signature help
    vim.keymap.set('i', '<C-h>', vim.lsp.buf.signature_help, { buffer = bufnr })
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr, desc = "Hover documentation" })
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
    -- 'grr' mirrors the aerial outline pane (autojump=true): the references land in
    -- the quickfix list, moving through them live-previews each location in the
    -- window we came from, and <CR> confirms the previewed spot and closes the list.
    vim.keymap.set('n', 'grr', function()
      local origin_win = vim.api.nvim_get_current_win()
      -- Snapshot where we started so a cancel (anything but <CR>) can restore it;
      -- live preview drags origin_win across files, which is jarring to abandon.
      local origin_buf = vim.api.nvim_win_get_buf(origin_win)
      local origin_view = vim.api.nvim_win_call(origin_win, vim.fn.winsaveview)
      vim.lsp.buf.references(nil, {
        on_list = function(list)
          vim.fn.setqflist({}, ' ', list)
          vim.cmd('copen')
          local qf_buf = vim.api.nvim_get_current_buf()
          local confirmed = false
          local ns = vim.api.nvim_create_namespace('GrReferencesHl')
          local hl_buf -- buffer the last highlight was placed in, so we can clear it

          local function clear_hl()
            if hl_buf and vim.api.nvim_buf_is_valid(hl_buf) then
              vim.api.nvim_buf_clear_namespace(hl_buf, ns, 0, -1)
            end
            hl_buf = nil
          end

          -- Jump origin_win to the entry under the cursor without leaving the list,
          -- and highlight the exact reference span (lnum/col..end_lnum/end_col).
          local function preview()
            if not vim.api.nvim_win_is_valid(origin_win) then return end
            local entry = vim.fn.getqflist()[vim.fn.line('.')]
            if not entry or entry.valid == 0 or entry.bufnr == 0 then return end
            -- Let nvim_win_set_buf do the loading rather than bufload()ing first:
            -- it runs the read with the buffer already in origin_win, so the
            -- window-local fold options the FileType autocmd sets actually stick.
            -- bufload() would run that autocmd in a throwaway autocmd window.
            vim.api.nvim_win_set_buf(origin_win, entry.bufnr)
            vim.api.nvim_win_set_cursor(origin_win, { entry.lnum, math.max((entry.col or 1) - 1, 0) })
            vim.api.nvim_win_call(origin_win, function() vim.cmd('normal! zz') end)

            clear_hl()
            local s = { entry.lnum - 1, math.max((entry.col or 1) - 1, 0) }
            local end_lnum = (entry.end_lnum ~= 0 and entry.end_lnum or entry.lnum)
            local end_col = (entry.end_col ~= 0 and entry.end_col or (entry.col or 1))
            vim.hl.range(entry.bufnr, ns, 'IncSearch', s, { end_lnum - 1, end_col - 1 })
            hl_buf = entry.bufnr
          end

          -- Put origin_win back to the pre-'grr' buffer and view.
          local function restore()
            if not vim.api.nvim_win_is_valid(origin_win) or not vim.api.nvim_buf_is_valid(origin_buf) then return end
            vim.api.nvim_win_set_buf(origin_win, origin_buf)
            vim.api.nvim_win_call(origin_win, function() vim.fn.winrestview(origin_view) end)
          end

          local grp = vim.api.nvim_create_augroup('GrReferencesPreview', { clear = true })
          -- Live preview as the cursor moves through the list (the autojump part).
          -- 'nested' is load-bearing: autocmds don't fire autocmds by default, so
          -- without it the read this triggers skips filetype detection and every
          -- previewed buffer opens with no treesitter highlighting and no folds.
          vim.api.nvim_create_autocmd('CursorMoved', {
            group = grp, buffer = qf_buf, nested = true, callback = preview,
          })
          -- The list going away drops the preview highlight either way; closing it
          -- any other way (q, :cclose, switching windows) also restores the origin.
          vim.api.nvim_create_autocmd('BufWinLeave', {
            group = grp,
            buffer = qf_buf,
            callback = function()
              clear_hl()
              if not confirmed then restore() end
            end,
          })

          -- <CR>: confirm the previewed location, close the list, land in the buffer.
          vim.keymap.set('n', '<CR>', function()
            confirmed = true
            preview()
            vim.cmd('cclose')
            if vim.api.nvim_win_is_valid(origin_win) then
              vim.api.nvim_set_current_win(origin_win)
            end
          end, { buffer = qf_buf, nowait = true, desc = 'Jump to reference and close' })

          preview() -- preview the first entry right away
        end,
      })
    end, { buffer = bufnr, desc = "Find references" })
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code action" })
    vim.keymap.set('n', 'rn', vim.lsp.buf.rename, { buffer = bufnr, desc = "Rename" })
  end,
})

-- Add format on save
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('LspFormatOnSave', {}),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    if client and client:supports_method("textDocument/formatting", bufnr) then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format { async = false, id = args.data.client_id }
        end,
      })
    end
  end
})

-- DIAGNOSTICS
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = {
    true,
    reverse = true
  }
})

-- COMMENT KEYWORDS (NOTE: / TODO: / FIXME:) highlighting — comments only.
-- Plugin-free (no todo-comments.nvim): pure matchadd. matchadd has no notion of
-- "comment", so to scope it we anchor each pattern to the buffer's comment leader
-- (the part of &commentstring before %s, e.g. '--', '#', '//') and require a
-- trailing ':'. The leader is buffer-local and matchadd is window-local, so we
-- rebuild the matches on every buffer/window/filetype enter, first deleting the
-- ones we previously added (tracked in a window var). \C forces case sensitivity
-- so only ALL-CAPS keywords match; priority 200 beats treesitter's default 100 so
-- the keyword shows through the comment treesitter already colored.
local todo_keywords = {
  { kw = 'NOTE',  group = 'TodoNote' },  -- green,       non-intrusive
  { kw = 'TODO',  group = 'TodoTodo' },  -- yellow,      standard
  { kw = 'FIXME', group = 'TodoFixme' }, -- red/magenta, intrusive
}

local function set_todo_highlights()
  vim.api.nvim_set_hl(0, 'TodoNote', { fg = '#9ece6a' })               -- green  (calm)
  vim.api.nvim_set_hl(0, 'TodoTodo', { fg = '#e0af68', bold = true })  -- yellow (standard)
  vim.api.nvim_set_hl(0, 'TodoFixme', { fg = '#f7768e', bold = true }) -- red    (loud)
end
set_todo_highlights()
-- Re-assert after a colorscheme load, which clears any custom highlight groups.
vim.api.nvim_create_autocmd('ColorScheme', { callback = set_todo_highlights })

-- Inline markdown `code` spans: orange text, no background. Two layers
-- paint these: the treesitter capture (@markup.raw.markdown_inline -- tokyonight's
-- blue box) and render-markdown.nvim's extmark (RenderMarkdownCodeInline). bg=NONE
-- alone only makes the extmark transparent, letting the treesitter blue bleed
-- through, so we override BOTH. Re-asserted on ColorScheme like the todo groups.
local function set_markdown_highlights()
  local inline = { fg = '#ff9e64', bg = 'NONE' }
  vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', inline)
  vim.api.nvim_set_hl(0, '@markup.raw.markdown_inline', inline)
  vim.api.nvim_set_hl(0, '@markup.raw', inline)
end
set_markdown_highlights()
vim.api.nvim_create_autocmd('ColorScheme', { callback = set_markdown_highlights })

local function refresh_todo_matches()
  -- Drop the matches we added on a previous visit to this window.
  for _, id in ipairs(vim.w.todo_match_ids or {}) do pcall(vim.fn.matchdelete, id) end
  vim.w.todo_match_ids = {}

  -- Comment leader = the text before %s in 'commentstring'. No commentstring
  -- (e.g. plain text buffers) -> nothing to anchor to, so skip.
  local leader = (vim.bo.commentstring or ''):match('^(.-)%s*%%s')
  if not leader or leader == '' then return end
  leader = vim.fn.escape(leader, [[\/.*$^~[]]) -- escape regex metachars in the leader

  local ids = {}
  for _, k in ipairs(todo_keywords) do
    -- \C  leader  .\{-} (lazy, allows code before the comment)  \zs (highlight
    -- starts here)  \<KW\>  \ze: (the required colon, kept uncolored).
    local pat = [[\C]] .. leader .. [[.\{-}\zs\<]] .. k.kw .. [[\>\ze:]]
    local id = vim.fn.matchadd(k.group, pat, 200)
    if id ~= -1 then table.insert(ids, id) end
  end
  vim.w.todo_match_ids = ids
end

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'FileType' }, {
  callback = refresh_todo_matches,
})

-- SETUP NVIM-TREESITTER
require('nvim-treesitter').install { "c", "lua", "markdown", "markdown_inline", "python", "zig", "superhtml", "wgsl" }

vim.filetype.add({ extension = { wgsl = "wgsl" } })

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'wgsl', 'zig', 'python', 'lua' },
  callback = function()
    vim.treesitter.start()                                            -- highlighting
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'               -- folds
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation
  end,
})

vim.o.foldlevelstart = 99

-- :RegisterCondaKernels — make every conda env that has ipykernel installed visible
-- to JupyterLab by registering it as a user-level Jupyter kernel spec. Re-run after
-- creating new envs. Skips 'base' and 'nvim' (the latter hosts JupyterLab itself,
-- not a kernel). Explicit user-level specs beat nb_conda_kernels auto-detection:
-- they work in every frontend with zero traitlets config.
vim.api.nvim_create_user_command('RegisterCondaKernels', function()
  -- Use `conda env list --json` rather than parsing the plaintext output: the
  -- text format is whitespace-delimited and breaks when the env path contains
  -- a space (e.g. `C:\Users\Caio Castro\...`), which silently dropped every
  -- env on this machine and made the command a no-op.
  local script = [[
$envs = (conda env list --json | ConvertFrom-Json).envs
foreach ($p in $envs) {
  if ($p -notlike '*\envs\*') { continue }   # skips base (no /envs/ segment)
  $name = Split-Path -Leaf $p
  if ($name -eq 'nvim') { continue }         # hosts JupyterLab itself, not a kernel
  $py = Join-Path $p 'python.exe'
  if (-not (Test-Path $py)) { continue }
  & $py -c "import ipykernel" 2>$null
  if ($LASTEXITCODE -eq 0) {
    & $py -m ipykernel install --user --name $name --display-name "Python ($name)"
  }
}
]]
  local tmp = vim.fn.tempname() .. '.ps1'
  vim.fn.writefile(vim.split(script, '\n'), tmp)
  local out = vim.fn.system({ 'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', tmp })
  vim.fn.delete(tmp)
  if vim.v.shell_error ~= 0 then
    vim.notify('RegisterCondaKernels failed:\n' .. out, vim.log.levels.ERROR)
  else
    vim.notify(out ~= '' and out or 'RegisterCondaKernels: nothing to do', vim.log.levels.INFO)
  end
end, { desc = 'Register every conda env (with ipykernel) as a Jupyter kernel spec' })

-- JUPYTER (neopyter → JupyterLab in the browser)  (prefix: <leader>j)
-- Notebooks are `*.ju.py` files with `# %%` cell separators. Neopyter mirrors the
-- buffer into a paired .ipynb open in JupyterLab and runs cells there; all output
-- (text, plots, dataframes) renders in the browser tab, nothing inside nvim.
-- For sortable/filterable dataframe tables, put this in the notebook's first cell:
--   from itables import init_notebook_mode; init_notebook_mode()
-- The variable-inspector panel lives in JupyterLab's right sidebar.

-- Move the cursor to the line after the next `# %%` separator; no-op on last cell.
local function jupyter_next_cell()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = cur + 1, #lines do
    if lines[i]:match('^#%s*%%%%') then
      vim.api.nvim_win_set_cursor(0, { math.min(i + 1, #lines), 0 })
      return
    end
  end
end

-- Launch JupyterLab from the 'nvim' conda env, rooted at the cwd, in a bottom
-- pane (native wezterm split when hosted in wezterm, else an nvim :terminal
-- split — mirrors <leader>wt). The pane shows server logs; JupyterLab opens the
-- browser tab itself. Start order matters in direct mode: nvim must already be
-- running (it hosts the RPC server the JupyterLab extension connects to).
local function jupyter_lab_start()
  local py = vim.g.python3_host_prog
  if vim.fn.executable(py) == 0 then
    vim.notify("JupyterLab env not found: " .. py .. "\nCreate it: conda create --prefix "
      .. "%USERPROFILE%\\.conda\\envs\\nvim python pynvim jupyterlab, then pip install "
      .. "neopyter lckr_jupyterlab_variableinspector itables", vim.log.levels.ERROR)
    return
  end
  local cwd = vim.fn.getcwd()
  if vim.env.WEZTERM_PANE then
    vim.fn.jobstart({ 'wezterm', 'cli', 'split-pane', '--bottom', '--cwd', cwd,
      '--', py, '-m', 'jupyterlab' }, { detach = true })
  else
    vim.cmd('belowright new')
    vim.fn.jobstart({ py, '-m', 'jupyterlab' }, { term = true, cwd = cwd })
  end
end

vim.keymap.set('n', '<leader>jl', jupyter_lab_start,
  { silent = true, desc = 'Jupyter: launch JupyterLab (browser)' })

-- Cell keymaps, gated to *.ju.py buffers (the only ones neopyter attaches to).
-- <C-CR>/<S-CR> are mapped in normal AND insert mode so a cell can run without
-- leaving insert (depends on the CSI-u encoding from wezterm.lua). Run-and-next
-- sends the run first, then moves the nvim cursor: neopyter's cursor-sync event
-- arrives after the run command on the same connection, so the run still targets
-- the cell the cursor was in.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(args)
    local bufname = vim.api.nvim_buf_get_name(args.buf)
    if not bufname:match('%.ju%.py$') then return end
    -- Pre-create the paired .ipynb (minimal empty nbformat 4) if it's missing,
    -- BEFORE neopyter's attach runs (FileType fires before BufWinEnter). With the
    -- file on disk, attach takes the "exists" path (open + full sync) and never
    -- calls the createNew RPC — whose response the Lab extension fails to
    -- serialize (@msgpack/msgpack "Too deep objects in depth" on the returned
    -- widget object; neopyter 0.4.0). Path mirrors neopyter's filename_mapper:
    -- fnamemodify ':r:r:r' + '.ipynb'  (sandbox.ju.py -> sandbox.ipynb).
    local ipynb = vim.fn.fnamemodify(bufname, ':r:r:r') .. '.ipynb'
    if not vim.uv.fs_stat(ipynb) then
      local f = io.open(ipynb, 'w')
      if f then
        f:write('{"cells":[],"metadata":{},"nbformat":4,"nbformat_minor":5}\n')
        f:close()
      end
    end
    local function map(modes, lhs, rhs, desc)
      vim.keymap.set(modes, lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
    end
    local function run_cell_and_next()
      vim.cmd('Neopyter run current')
      jupyter_next_cell()
    end
    -- Recovery for the attach-order trap: neopyter creates the paired .ipynb only
    -- while attaching a buffer, and skips that silently if the JupyterLab tab
    -- isn't connected yet — re-entering the buffer later never retries. Unloading
    -- the buffer makes neopyter forget it (BufUnload); reopening runs a fresh
    -- attach, which creates the .ipynb and full-syncs. Use after the Lab tab is up.
    map('n', '<leader>ji', function()
      local file = vim.api.nvim_buf_get_name(0)
      local view = vim.fn.winsaveview()
      vim.cmd('silent! write')
      vim.cmd('bdelete')
      vim.cmd('edit ' .. vim.fn.fnameescape(file))
      vim.fn.winrestview(view)
    end, 'Jupyter: re-attach buffer (create/pair .ipynb)')
    map({ 'n', 'i' }, '<C-CR>', '<Cmd>Neopyter run current<CR>', 'Run cell (Ctrl+Enter)')
    map({ 'n', 'i' }, '<S-CR>', run_cell_and_next, 'Run cell + next (Shift+Enter)')
    map('n', '<leader>jc', '<Cmd>Neopyter run current<CR>', 'Jupyter: run # %% cell')
    map('n', '<leader>jn', run_cell_and_next, 'Jupyter: run cell + move to next')
    map('n', '<leader>ja', '<Cmd>Neopyter run all<CR>', 'Jupyter: run all cells')
    map('n', '<leader>js', '<Cmd>Neopyter sync current<CR>', 'Jupyter: re-sync buffer → notebook')
    -- Interrupt has no native subcommand; route it through Lab's command registry.
    map('n', '<leader>jx', '<Cmd>Neopyter execute kernelmenu:interrupt<CR>',
      'Jupyter: interrupt (stop running cell)')
    map('n', '<leader>jR', '<Cmd>Neopyter kernel restart<CR>', 'Jupyter: restart kernel')
  end,
})
