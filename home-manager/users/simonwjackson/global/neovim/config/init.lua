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

opt.spell = true
opt.spelllang = { "en_us" }
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

-- use("editorconfig/editorconfig-vim")
--
-- -- incremental search improved
-- use("haya14busa/is.vim")
--
-- vim.cmd([[
-- " ----------------------------------------------------------------------------
-- "  - Write to file even when it does not exist
-- " ----------------------------------------------------------------------------
--
-- function! s:WriteCreatingDirs()
--     let l:file=expand("%")
--     if empty(getbufvar(bufname("%"), '&buftype')) && l:file !~# '\v^\w+\:\/'
--         let dir=fnamemodify(l:file, ':h')
--         if !isdirectory(dir)
--             call mkdir(dir, 'p')
--         endif
--     endif
--     write
-- endfunction
--
-- command! W call s:WriteCreatingDirs()
--
--
--
--
-- " copy current file name (relative/absolute) to system clipboard (Linux version)
-- if has("gui_gtk") || has("gui_gtk2") || has("gui_gnome") || has("unix")
--     " relative path (src/foo.txt)
--     nnoremap <leader>cf :let @+=expand("%")<CR>
--
--     " absolute path (/something/src/foo.txt)
--     nnoremap <leader>cF :let @+=expand("%:p")<CR>
--
--     " filename (foo.txt)
--     nnoremap <leader>ct :let @+=expand("%:t")<CR>
--
--     " directory name (/something/src)
--     nnoremap <leader>ch :let @+=expand("%:p:h")<CR>
-- endif
--
-- "
--
-- " ============================================================================
-- "  => Scratch Pad (testing)
-- " ============================================================================
--
-- augroup CursorLineOnlyInActiveWindow
--     autocmd!
--     autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
--     autocmd WinLeave * setlocal nocursorline
-- augroup END
--
-- augroup TodayFile
--     autocmd FileReadPre,BufWritePost ${HOME}/Documents/notes/Today.md execute "silent !gawk -i inplace 'BEGIN {p=1} /Agenda/ {print;system(\"echo; khal list; echo\");p=0} /^-+$/ {p=1} p' %" | edit
-- augroup END
--
--
--
--
-- " Reselect visual selection after indenting
-- vnoremap < <gv
-- vnoremap > >gv
--
-- " Maintain the cursor position when yanking a visual selection
-- vnoremap y myy`y
-- vnoremap Y myY`y
--
-- " Keep it centered
-- nnoremap n nzzzv
-- nnoremap N Nzzzv
-- nnoremap J mzJ`z
--
-- " Open the current file in the default program
-- nmap <leader>x :!xdg-open %<cr><cr>
--
-- " Common configs
-- nmap <leader>vv :edit ~/.config/nvim/init.vim<cr>
--
-- " Allow gf to open non-existent files
-- map gf :edit <cfile><cr>
--
-- nnoremap <A-L> :tabnext<CR>
-- nnoremap <A-H> :tabprevious<CR>
--
-- map <A-x> :confirm q<CR>
--
-- if has('nvim') && executable('nvr')
--   let $GIT_EDITOR = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
-- endif
--
-- ]])
--
-- function Sgpt(type, prompt)
-- 	-- Get the current selection
-- 	local selection = vim.fn.getreg("v")
--
-- 	-- Determine the range to use based on the selection
-- 	local range_start, range_end
-- 	if selection ~= "" then -- If selection is not empty, it means some text has been selected.
-- 		vim.api.nvim_command('echo "SELECTION MADE!"')
--
-- 		range_start = vim.api.nvim_buf_get_mark(0, "<")
-- 		range_end = vim.api.nvim_buf_get_mark(0, ">")
--
-- 		range_start = { range_start[1], range_start[2] }
-- 		range_end = { range_end[1], range_end[2] }
-- 	else
-- 		range_start, range_end = 1, vim.fn.line("$")
-- 	end
--
-- 	-- Yank the specified range
-- 	vim.api.nvim_command(range_start .. "," .. range_end .. "y")
--
-- 	-- Create temporary files
-- 	local output_file = vim.fn.tempname()
-- 	local input_file = vim.fn.tempname()
--
-- 	-- Write yanked text to the input file
-- 	vim.fn.writefile(vim.fn.split(vim.fn.getreg('"'), "\n"), input_file)
--
-- 	-- local cmd = string.format(
-- 	--   "cat %s | sgpt %s '%s' | tee /dev/tty > %s && nvr %s +'set ft=%s' +'edit'",
-- 	--   input_file, type, prompt, output_file, output_file, vim.bo.filetype)
--
-- 	local cmd = string.format("cat %s", input_file)
--
-- 	-- Execute the terminal command
-- 	vim.api.nvim_command("vsp | terminal " .. cmd)
-- end
