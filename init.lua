-- Bootstrap lazy.nvim
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

-- KEYMAPS
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Open init.lua
vim.keymap.set('n', '<leader>rc', ':e $MYVIMRC<CR>', { desc = 'Open [R]C config' })
-- Open Lazy
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'Lazy.nvim UI' })

-- SETUP LAZY.NVIM
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
			"neovim/nvim-lspconfig",
		}
	},
	-- configure any other settings here. see documentation for detailes.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})

-- SETUP NVIM-TREESITTER
require 'nvim-treesitter'.install { "c", "lua", "markdown", "markdown_inline", "python", "zig", "superhtml", "wgsl", "zig" }
-- highlighting
vim.api.nvim_create_autocmd('FileType', {
	pattern = { '<filetype>' },
	callback = function() vim.treesitter.start() end,
})
-- folds
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- indentation
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

-- SETUP LSP
vim.lsp.enable({'pyrefly'})
--
-- vim.api.nvim_create_autocmd('LspAttach', {
-- 	group = vim.api.nvim_create_augroup('my.lsp', {}),
-- 	callback = function(args)
-- 		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
-- 		if client:supports_method('textDocument/implementation') then
-- 			-- Create a keymap for vim.lsp.buf.implementation ...
-- 		end
--
-- 		-- Enable auto-completion. Note: Use CTRL-Y to select an item. |complete_CTRL-Y|
-- 		if client:supports_method('textDocument/completion') then
-- 			-- Optional: trigger autocompletion on EVERY keypress. May be slow!
-- 			-- local chars = {}; for i = 32, 126 do table.insert(chars, string.char(i)) end
-- 			-- client.server_capabilities.completionProvider.triggerCharacters = chars
--
-- 			vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
-- 		end
--
-- 		-- Auto-format ("lint") on save.
-- 		-- Usually not needed if server supports "textDocument/willSaveWaitUntil".
-- 		if not client:supports_method('textDocument/willSaveWaitUntil')
-- 		    and client:supports_method('textDocument/formatting') then
-- 			vim.api.nvim_create_autocmd('BufWritePre', {
-- 				group = vim.api.nvim_create_augroup('my.lsp', { clear = false }),
-- 				buffer = args.buf,
-- 				callback = function()
-- 					vim.lsp.buf.format({ bufnr = args.buf, id = client.id, timeout_ms = 1000 })
-- 				end,
-- 			})
-- 		end
-- 	end,
-- })
