-- =============================================================================
-- OS dependencies (Windows; install manually unless marked auto-installed).
-- Single source of truth for what a fresh machine needs before this config runs.
-- =============================================================================
--
-- Terminal emulator (molten image rendering + <leader>wt native panes)
--   wezterm                -> winget install wez.wezterm
--                             (optional — <leader>wt falls back to nvim :terminal
--                              when not in a wezterm session; molten image
--                              rendering on Windows degrades without it)
--
-- Git UI (floating panel via <leader>gg)
--   lazygit                -> winget install JesseDuffield.lazygit
--
-- Tree-sitter parser build chain
--   LLVM (clang)           -> winget install LLVM.LLVM
--   MSVC Build Tools       -> winget install Microsoft.VisualStudio.2022.BuildTools
--                             (need VCTools workload + Windows 10 SDK for libc headers)
--   tree-sitter CLI        -> winget install tree-sitter.tree-sitter-cli
--                             (auto-installed below if missing)
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
-- Python provider + Jupyter kernels (for molten-nvim)
--   conda env 'nvim' at %USERPROFILE%\.conda\envs\nvim
--     packages: pynvim, jupyter_client, ipykernel
--   each conda env you want as a Jupyter kernel needs `ipykernel` installed;
--     register them in bulk via :RegisterCondaKernels (defined later)
-- =============================================================================

-- PYTHON PROVIDER (must come before lazy setup so :UpdateRemotePlugins uses it)
-- Resolves to %USERPROFILE%\.conda\envs\nvim\python.exe at runtime, so the path
-- is portable across machines as long as the env lives in that conventional spot.
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

-- ENSURE TREE-SITTER CLI (needed by nvim-treesitter main branch to compile parsers)
-- Route through the shell (string form) because winget is a Windows App Execution Alias
-- (reparse point), which vim.fn.system's list form rejects as non-executable.
if vim.fn.executable('tree-sitter') == 0 then
  vim.notify('tree-sitter CLI not found. Installing via winget...', vim.log.levels.INFO)
  local out = vim.fn.system(
    'winget install --id tree-sitter.tree-sitter-cli -e ' ..
    '--accept-source-agreements --accept-package-agreements'
  )
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to install tree-sitter CLI:\n' .. out ..
      '\nInstall manually: winget install tree-sitter.tree-sitter-cli', vim.log.levels.ERROR)
  else
    vim.notify('tree-sitter CLI installed. Restart nvim so PATH picks it up.', vim.log.levels.WARN)
  end
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
      "benlubas/molten-nvim",
      version = "^1.0.0",
      dependencies = { "willothy/wezterm.nvim" },
      ft = { "python", "markdown" },
      init = function()
        vim.g.molten_image_provider = "wezterm"
        vim.g.molten_output_win_max_height = 20
        vim.g.molten_auto_open_output = false
        vim.g.molten_wrap_output = true
        vim.g.molten_virt_text_output = true
        vim.g.molten_virt_lines_off_by_1 = false
        vim.g.molten_output_show_more = true
        vim.g.molten_use_border_highlights = true
        -- use_border_highlights only works when the border is a table, not a
        -- string preset like "rounded" — molten recolors each side per output state.
        vim.g.molten_output_win_border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      end,
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

-- Force every lazy-loaded plugin onto the runtimepath before :UpdateRemotePlugins
-- runs, so ft/event/cmd-gated plugins (e.g. molten-nvim) get their rplugin/python3
-- commands into the manifest. Without this, the scan only sees eagerly-loaded
-- plugins and remote commands like :MoltenInit silently never register.
vim.api.nvim_create_autocmd('User', {
  pattern = { 'LazyInstall', 'LazyUpdate', 'LazySync' },
  once = true,
  callback = function()
    local names = vim.tbl_map(function(p) return p.name end, require('lazy').plugins())
    require('lazy').load({ plugins = names })
    vim.cmd('UpdateRemotePlugins')
  end,
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
  vim.fn.jobstart('lazygit', {
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
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, { buffer = bufnr, desc = "Find references" })
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
-- to molten by registering it as a user-level Jupyter kernel spec. Re-run after
-- creating new envs. Skips 'base' and 'nvim' (the latter is molten's python provider,
-- not a kernel). nb_conda_kernels' auto-detection does NOT work here because molten
-- calls jupyter_client.kernelspec directly, bypassing the traitlets config that
-- nb_conda_kernels hooks into.
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
  if ($name -eq 'nvim') { continue }         # molten's python provider, not a kernel
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

-- MOLTEN (Jupyter) CELL HELPERS
local function molten_cell_range()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local first, last = 1, #lines
  for i = cur, 1, -1 do
    if lines[i]:match('^#%s*%%%%') then
      first = i + 1; break
    end
  end
  for i = cur + 1, #lines do
    if lines[i]:match('^#%s*%%%%') then
      last = i - 1; break
    end
  end
  return first, last
end

local function molten_run_cell()
  local first, last = molten_cell_range()
  vim.fn.setpos("'<", { 0, first, 1, 0 })
  vim.fn.setpos("'>", { 0, last, 2147483647, 0 })
  vim.cmd('MoltenEvaluateVisual')
end

local function molten_run_cell_and_next()
  molten_run_cell()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = cur + 1, #lines do
    if lines[i]:match('^#%s*%%%%') then
      vim.api.nvim_win_set_cursor(0, { math.min(i + 1, #lines), 0 })
      return
    end
  end
end

-- List every running kernel. MoltenRunningKernels(false) returns the global set
-- (pass true for buffer-local only); :MoltenInfo also shows them but mixes in the
-- not-yet-running available kernels, so a plain notify is clearer for "what's live".
local function molten_list_kernels()
  local ok, running = pcall(vim.fn.MoltenRunningKernels, false)
  if not ok or vim.tbl_isempty(running) then
    vim.notify('Molten: no running kernels', vim.log.levels.INFO)
    return
  end
  vim.notify('Molten running kernels:\n  ' .. table.concat(running, '\n  '), vim.log.levels.INFO)
end

-- Kill this buffer's kernel AND close the wezterm pane it rendered images into.
-- With molten_image_provider = "wezterm", MoltenInit splits off a terminal pane
-- (molten_split_direction, default "right") for images; :MoltenDeinit shuts the
-- kernel down and clears the nvim-side output windows, but molten only closes that
-- split on full nvim exit — so close it here by killing the pane in the split dir.
local function molten_kill()
  local ok, running = pcall(vim.fn.MoltenRunningKernels, true) -- buffer-local kernels
  if not ok or vim.tbl_isempty(running) then
    vim.notify('Molten: no kernel in this buffer', vim.log.levels.INFO)
    return
  end
  -- Locate molten's image pane (the split next to nvim) before deinit. wezterm.nvim's
  -- get_pane_direction returns the neighbour pane id directly, trimmed — wrapping the
  -- raw exec_sync in pcall was capturing its (ok, stdout, stderr) boolean, not the id.
  local wok, wez = pcall(require, 'wezterm')
  local dir = ({ right = 'Right', left = 'Left', top = 'Up', bottom = 'Down' })
      [vim.g.molten_split_direction or 'right'] or 'Right'
  -- No explicit pane arg: wezterm infers it from $WEZTERM_PANE (inherited by the
  -- subprocess), so the lookup is relative to nvim's own pane. Passing the id would
  -- feed a number into vim.system, which only accepts string args.
  local pane_id = wok and wez.get_pane_direction(dir)
  vim.cmd('MoltenDeinit')
  if pane_id then
    wez.exec_sync({ 'cli', 'kill-pane', '--pane-id', tostring(pane_id) })
  end
end

-- Jupyter / Molten keymaps  (prefix: <leader>j)
vim.keymap.set('n', '<leader>ji', ':MoltenInit<CR>', { silent = true, desc = 'Jupyter: init kernel' })
vim.keymap.set('n', '<leader>jx', ':MoltenInterrupt<CR>',
  { silent = true, desc = 'Jupyter: interrupt (stop running cell)' })
vim.keymap.set('n', '<leader>jR', ':MoltenRestart!<CR>', { silent = true, desc = 'Jupyter: restart kernel' })
vim.keymap.set('n', '<leader>jk', molten_list_kernels, { silent = true, desc = 'Jupyter: list running kernels' })
vim.keymap.set('n', '<leader>jK', molten_kill,
  { silent = true, desc = 'Jupyter: kill kernel + image pane (this buffer)' })
vim.keymap.set('n', '<leader>jd', ':MoltenDelete<CR>', { silent = true, desc = 'Jupyter: delete cell output' })
vim.keymap.set('n', '<leader>jh', ':MoltenHideOutput<CR>', { silent = true, desc = 'Jupyter: hide output' })
vim.keymap.set('n', '<leader>js', ':noautocmd MoltenEnterOutput<CR>',
  { silent = true, desc = 'Jupyter: show / enter output' })
vim.keymap.set('n', '<leader>jl', ':MoltenEvaluateLine<CR>', { silent = true, desc = 'Jupyter: run line' })
vim.keymap.set('v', '<leader>jv', ':<C-u>MoltenEvaluateVisual<CR>gv', { silent = true, desc = 'Jupyter: run selection' })
vim.keymap.set('n', '<leader>jr', ':MoltenReevaluateCell<CR>', { silent = true, desc = 'Jupyter: re-evaluate cell' })
vim.keymap.set('n', '<leader>jc', molten_run_cell, { silent = true, desc = 'Jupyter: run # %% cell' })
vim.keymap.set('n', '<leader>jn', molten_run_cell_and_next, { silent = true, desc = 'Jupyter: run cell + move to next' })

-- VSCode-style cell shortcuts, python buffers only. Mapped in normal AND insert mode
-- so you can run a cell without leaving insert; the function rhs inserts nothing and
-- keeps the current mode (depends on the CSI-u <C-CR>/<S-CR> encoding from wezterm.lua).
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(args)
    vim.keymap.set({ 'n', 'i' }, '<C-CR>', molten_run_cell,
      { buffer = args.buf, silent = true, desc = 'Run cell (Ctrl+Enter)' })
    vim.keymap.set({ 'n', 'i' }, '<S-CR>', molten_run_cell_and_next,
      { buffer = args.buf, silent = true, desc = 'Run cell + next (Shift+Enter)' })
  end,
})
