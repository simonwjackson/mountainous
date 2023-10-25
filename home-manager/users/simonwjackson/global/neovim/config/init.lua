local opt = vim.opt
local g = vim.g
local api = vim.api
local cmd = vim.api.nvim_command

-------------------------------------- options ------------------------------------------
opt.laststatus = 3 -- global statusline
opt.showmode = false

opt.clipboard = "unnamedplus"
opt.cursorline = true

-- Indenting
opt.expandtab = true
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

opt.fillchars = { eob = " " }
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"

-- Numbers
opt.number = false
opt.numberwidth = 2
opt.ruler = false

-- disable nvim intro
opt.shortmess:append("sI")

opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.timeoutlen = 400
opt.undofile = true
opt.scrollback = 100000

opt.showtabline = 0

-- interval for writing swap file to disk, also used by gitsigns
opt.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
opt.whichwrap:append("<>[]hl")

g.mapleader = " "

--- CUSTOM ---
opt.splitkeep = "screen" -- keeps the same screen screen lines in all split windows

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

-------------------------------------- Custom Functions -----------------------------------------

vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct

require("lazy").setup("plugins")

vim.cmd([[ colorscheme onedark ]])
vim.cmd([[ autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif ]])

-- vim.cmd([[
-- function! Format()
--     if (&ft=='typescript' || &ft=='typescriptreact' || &ft=='javascript' || &ft=='javascriptreact')
--       if ((filereadable('.eslintrc.js') || filereadable('.eslintrc.json')))
--         :EslintFixAll
--       else
--         :lua vim.lsp.buf.format()
--       endif
--     elseif (&ft=='nix')
--       let save_cursor = getcurpos()
--       :silent %!nixpkgs-fmt
--       call setpos('.', save_cursor)
--     elseif (&ft=='astro')
--       if (filereadable('prettier.config.mjs') || filereadable('prettier.config.cjs') || filereadable('prettier.config.js'))
--         let save_cursor = getcurpos()
--         :silent %!prettier --parser astro
--         call setpos('.', save_cursor)
--       endif
--     elseif (&ft=='sh')
--       :Shfmt
--     elseif (&ft=='lua')
--       :lua vim.lsp.buf.format()
--     endif
-- endfunction
--
-- autocmd BufWritePre * call Format()
-- ]])
