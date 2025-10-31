-- OS dependencies (setup manually)
-- ripgrep -> winget install BurntSushi.ripgrep.MSVC
-- fd -> winget install sharkdp.fd

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
      opts = {},
      keys = {
        {
          "<leader>?",
          function()
            require("which-key").show({global = false})
          end,
          desc = "buffer Local Keymaps (which-key)",
        }
      }
    },

    {
      'Vigemus/iron.nvim'
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
        lualine_b = {'branch', 'diagnostics'},
        lualine_x = {'filetype'},
        lualine_y = {'lsp_status'},
    }
})

-- KEYMAPS | Keybindings
vim.keymap.set('n', '<leader>rc', ':e $MYVIMRC<CR>', { desc = 'Open [R]C config' }) -- Open init.lua
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'Lazy.nvim UI' }) -- Open Lazy
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>', { desc = 'Clear search highlight' })
vim.keymap.set('i', '<C-Space>', '<C-x><C-o>', { noremap = true, silent = true })
vim.keymap.set({'n', 'v'}, '<Space>', '<Nop>') -- space with no following letter has no effect on normal and visual mode
-- window
vim.keymap.set('t', '<Esc>', '<C-\\><C-N>', { desc = 'Normal Mode in terminal'})
-- terminal
vim.keymap.set('n', '<leader>wt', "<C-w>s<C-w>j:terminal<CR>") -- minimize terminal split
vim.keymap.set('t', '<Esc>', '<C-\\><C-N>', { desc = 'Normal Mode in terminal'})
vim.keymap.set('t', '<C-w>', "<C-\\><C-n><C-w>")
vim.keymap.set('n', '<C-g>', "3<C-w>_") -- minimize terminal split
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
  cmd = { 'pyrefly' , 'lsp' },
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

vim.lsp.enable({'luals', 'pyrefly', 'zls'})
-- activate completion
-- Use CTRL-Y to select an item. |complete_CTRL-Y|
vim.opt.completeopt = 'menuone,noselect,popup'
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLspConfig', {}),
    callback = function(args)
        local bufnr = args.buf
        vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

        -- Help with signature help
        vim.keymap.set('i', '<C-h>', vim.lsp.buf.signature_help, {buffer = bufnr})
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr, desc = "Hover documentation" })
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr, desc = "Go to definition" })
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, { buffer = bufnr, desc = "Find references" })
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code action" })
        vim.keymap.set('n', 'rn', vim.lsp.buf.rename, { buffer = bufnr, desc = "Rename" })
    end,
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
require 'nvim-treesitter'.install { "c", "lua", "markdown", "markdown_inline", "python", "zig", "superhtml", "wgsl", "zig" }
vim.api.nvim_create_autocmd('FileType', {
	pattern = { '<filetype>' },
	callback = function() vim.treesitter.start() end,
}) -- highlighting
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()' -- folds
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation

-- IRON REPL CONFIG
local iron = require("iron.core")
local view = require("iron.view")
local common = require("iron.fts.common")

iron.setup {
  config = {
    -- Whether a repl should be discarded or not
    scratch_repl = true,
    -- Your repl definitions come here
    repl_definition = {
      sh = {
        -- Can be a table or a function that
        -- returns a table (see below)
        command = {"cmd"}
      },
      python = {
        command = { "python" },  -- or { "ipython", "--no-autoindent" }
        format = common.bracketed_paste_python,
        block_dividers = { "# %%", "#%%" },
        env = {PYTHON_BASIC_REPL = "1"} --this is needed for python3.13 and up.
      }
    },
    -- set the file type of the newly created repl to ft
    -- bufnr is the buffer id of the REPL and ft is the filetype of the 
    -- language being used for the REPL. 
    repl_filetype = function(bufnr, ft)
      return ft
      -- or return a string name such as the following
      -- return "iron"
    end,
    -- Send selections to the DAP repl if an nvim-dap session is running.
    dap_integration = true,
    -- How the repl window will be displayed
    -- See below for more information
    repl_open_cmd = view.split.vertical.rightbelow("%40"),

    -- repl_open_cmd can also be an array-style table so that multiple 
    -- repl_open_commands can be given.
    -- When repl_open_cmd is given as a table, the first command given will
    -- be the command that `IronRepl` initially toggles.
    -- Moreover, when repl_open_cmd is a table, each key will automatically
    -- be available as a keymap (see `keymaps` below) with the names 
    -- toggle_repl_with_cmd_1, ..., toggle_repl_with_cmd_k
    -- For example,
    -- 
    -- repl_open_cmd = {
    --   view.split.vertical.rightbelow("%40"), -- cmd_1: open a repl to the right
    --   view.split.rightbelow("%25")  -- cmd_2: open a repl below
    -- }

  },
  -- Iron doesn't set keymaps by default anymore.
  -- You can set them here or manually add keymaps to the functions in iron.core
  keymaps = {
    toggle_repl = "<space>rr", -- toggles the repl open and closed.
    -- If repl_open_command is a table as above, then the following keymaps are
    -- available
    -- toggle_repl_with_cmd_1 = "<space>rv",
    -- toggle_repl_with_cmd_2 = "<space>rh",
    restart_repl = "<space>rR", -- calls `IronRestart` to restart the repl
    send_motion = "<space>sc",
    visual_send = "<space>sc",
    send_file = "<space>sf",
    send_line = "<space>sl",
    send_paragraph = "<space>sp",
    send_until_cursor = "<space>su",
    send_mark = "<space>sm",
    send_code_block = "<space><sb>",
    send_code_block_and_move = "<space><sn>",
    mark_motion = "<space>mc",
    mark_visual = "<space>mc",
    remove_mark = "<space>md",
    cr = "<space>s<cr>",
    interrupt = "<space>s<space>",
    exit = "<space>sq",
    clear = "<space>cl",
  },
  -- If the highlight is on, you can change how it looks
  -- For the available options, check nvim_set_hl
  highlight = {
    italic = true
  },
  ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
}

-- iron also has a list of commands, see :h iron-commands for all available commands
vim.keymap.set('n', '<space>rf', '<cmd>IronFocus<cr>')
vim.keymap.set('n', '<space>rh', '<cmd>IronHide<cr>')
