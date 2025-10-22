-- CONFIGS
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.termguicolors = true
vim.cmd('colorscheme unokai')

-- KEYMAPS
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Open init.lua
vim.keymap.set('n', '<leader>rc', ':e $MYVIMRC<CR>', { desc = 'Open [R]C config' })
-- Open Lazy
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'Lazy.nvim UI' })

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
  cmd = { 'pyrefly' },
  filetypes = { 'python' },
  root_markers = { '.git' },
  settings = {
  },
  on_exit = function(code, _, _)
      vim.notify("Closing Pyrefly LSP exited with code: " .. code, vim.log.levels.INFO)
  end,
}

vim.lsp.enable({'luals', 'pyrefly'})

-- DIAGNOSTICS
vim.diagnostic.config({
    virtual_text = true,
    severity_sort = {
        true,
        reverse = true
    }
})


-- SETUP LAZY.NVIM
-- local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- if not (vim.uv or vim.loop).fs_stat(lazypath) then
-- 	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
-- 	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
-- 	if vim.v.shell_error ~= 0 then
-- 		vim.api.nvim_echo({
-- 			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
-- 			{ out,                            "WarningMsg" },
-- 			{ "\nPress any key to exit..." },
-- 		}, true, {})
-- 		vim.fn.getchar()
-- 		os.exit(1)
-- 	end
-- end
-- vim.opt.rtp:prepend(lazypath)
-- require("lazy").setup({
-- 	spec = {
-- 		{
-- 			"folke/tokyonight.nvim",
-- 			lazy = false,
-- 			priority = 1000,
-- 			config = function()
-- 				vim.cmd([[colorscheme tokyonight]])
-- 			end,
-- 		},
-- 		-- {
-- 		-- 	"folke/trouble.nvim",
-- 		-- 	dependencies = { "nvim-tree/nvim-web-devicons" },
-- 		-- 	opts = {},
-- 		-- },
-- 		-- {
-- 		-- 	'sontungexpt/better-diagnostic-virtual-text',
-- 		-- 	config = function(_)
-- 		-- 		require('better-diagnostic-virtual-text').setup(opts)
-- 		-- 	end,
-- 		-- },
-- 		{
-- 			"nvim-treesitter/nvim-treesitter",
-- 			branch = "main",
-- 			lazy = false,
-- 			build = ":TSUpdate",
-- 		},
-- 		{
-- 			"neovim/nvim-lspconfig",
-- 		}
-- 	},
-- 	-- configure any other settings here. see documentation for detailes.
-- 	-- automatically check for plugin updates
-- 	checker = { enabled = true },
-- })
--
-- -- SETUP NVIM-TREESITTER
-- require 'nvim-treesitter'.install { "c", "lua", "markdown", "markdown_inline", "python", "zig", "superhtml", "wgsl", "zig" }
-- vim.api.nvim_create_autocmd('FileType', {
-- 	pattern = { '<filetype>' },
-- 	callback = function() vim.treesitter.start() end,
-- }) -- highlighting
-- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()' -- folds
-- vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation
--
-- -- SETUP LSP
-- vim.lsp.enable({'luals', })
