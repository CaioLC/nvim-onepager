-- OS dependencies (setup manually)
-- ripgrep -> winget install BurntSushi.ripgrep.MSVC
-- fd -> winget install sharkdp.fd
-- conda env 'nvim' -> pynvim, jupyter_client, ipykernel (for molten-nvim)

-- PYTHON PROVIDER (must come before lazy setup so :UpdateRemotePlugins uses it)
vim.g.python3_host_prog = 'C:/Users/c4ioc/.conda/envs/nvim/python.exe'

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
      build = ":UpdateRemotePlugins",
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
