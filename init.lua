-- OS dependencies (setup manually)
-- ripgrep -> winget install BurntSushi.ripgrep.MSVC
-- fd -> winget install sharkdp.fd
-- tree-sitter CLI -> winget install tree-sitter.tree-sitter-cli  (auto-installed below if missing)
-- LLVM (clang) -> required as the C compiler for tree-sitter parser builds (used via CC=clang)
--                 winget install LLVM.LLVM (installs to C:\Program Files\LLVM\bin and adds to PATH)
-- conda env 'nvim' -> pynvim, jupyter_client, ipykernel (for molten-nvim)

-- PYTHON PROVIDER (must come before lazy setup so :UpdateRemotePlugins uses it)
-- Resolves to %USERPROFILE%\.conda\envs\nvim\python.exe at runtime, so the path
-- is portable across machines as long as the env lives in that conventional spot.
vim.g.python3_host_prog = vim.fn.expand('$USERPROFILE') .. '/.conda/envs/nvim/python.exe'

-- Disable unused language providers to silence checkhealth warnings.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

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
      'nvim-telescope/telescope.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' }
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
        vim.g.molten_virt_lines_off_by_1 = true
      end,
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
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
require('lualine').setup({
  sections = {
    lualine_b = { 'branch', 'diagnostics' },
    lualine_x = { 'filetype' },
    lualine_y = { 'lsp_status' },
  }
})

-- KEYMAPS | Keybindings
vim.keymap.set('n', '<leader>rc', ':e $MYVIMRC<CR>', { desc = 'Open [R]C config' }) -- Open init.lua
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'Lazy.nvim UI' })            -- Open Lazy
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>', { desc = 'Clear search highlight' })
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>')                                    -- space with no following letter has no effect on normal and visual mode
-- terminal
vim.keymap.set('n', '<leader>wt', "<C-w>s<C-w>j:terminal<CR>", { desc = 'Open terminal in split below' })
vim.keymap.set('t', '<Esc>', '<C-\\><C-N>', { desc = 'Normal Mode in terminal' })
vim.keymap.set('t', '<C-w>', "<C-\\><C-n><C-w>")
vim.keymap.set('n', '<C-g>', "3<C-w>_", { desc = 'Maximize current window' })
-- folds
vim.keymap.set('n', '<leader>zm', 'zM', { desc = 'Fold all functions/structs' })
vim.keymap.set('n', '<leader>zr', 'zR', { desc = 'Unfold all' })
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
      runtime = {
        version = 'LuaJIT',
      }
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
-- activate completion
-- Use CTRL-Y to select an item. |complete_CTRL-Y|
vim.opt.completeopt = 'menuone,noselect,popup'
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

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

-- MOLTEN (Jupyter) CELL HELPERS
local function molten_cell_range()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local first, last = 1, #lines
  for i = cur, 1, -1 do
    if lines[i]:match('^#%s*%%%%') then first = i + 1; break end
  end
  for i = cur + 1, #lines do
    if lines[i]:match('^#%s*%%%%') then last = i - 1; break end
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

-- Jupyter / Molten keymaps  (prefix: <leader>j)
vim.keymap.set('n', '<leader>ji', ':MoltenInit<CR>',                  { silent = true, desc = 'Jupyter: init kernel' })
vim.keymap.set('n', '<leader>jR', ':MoltenRestart!<CR>',              { silent = true, desc = 'Jupyter: restart kernel' })
vim.keymap.set('n', '<leader>jd', ':MoltenDelete<CR>',                { silent = true, desc = 'Jupyter: delete cell output' })
vim.keymap.set('n', '<leader>jh', ':MoltenHideOutput<CR>',            { silent = true, desc = 'Jupyter: hide output' })
vim.keymap.set('n', '<leader>js', ':noautocmd MoltenEnterOutput<CR>', { silent = true, desc = 'Jupyter: show / enter output' })
vim.keymap.set('n', '<leader>jl', ':MoltenEvaluateLine<CR>',          { silent = true, desc = 'Jupyter: run line' })
vim.keymap.set('v', '<leader>jv', ':<C-u>MoltenEvaluateVisual<CR>gv', { silent = true, desc = 'Jupyter: run selection' })
vim.keymap.set('n', '<leader>jr', ':MoltenReevaluateCell<CR>',        { silent = true, desc = 'Jupyter: re-evaluate cell' })
vim.keymap.set('n', '<leader>jc', molten_run_cell,                    { silent = true, desc = 'Jupyter: run # %% cell' })
vim.keymap.set('n', '<leader>jn', molten_run_cell_and_next,           { silent = true, desc = 'Jupyter: run cell + move to next' })

-- VSCode-style cell shortcuts, python buffers only
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(args)
    vim.keymap.set('n', '<C-CR>', molten_run_cell,
      { buffer = args.buf, silent = true, desc = 'Run cell (Ctrl+Enter)' })
    vim.keymap.set('n', '<S-CR>', molten_run_cell_and_next,
      { buffer = args.buf, silent = true, desc = 'Run cell + next (Shift+Enter)' })
  end,
})
