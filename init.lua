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
      'nvim-telescope/telescope.nvim',
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
