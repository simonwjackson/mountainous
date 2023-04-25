vim.cmd([[
  let g:vimwiki_global_ext = 0
  let g:vimwiki_markdown_link_ext = 1
  let g:vimwiki_links_space_char = '-'
  let g:vimwiki_autowriteall = 1
  let g:vimwiki_syntax = 'markdown'
  let g:vimwiki_ext = '.md'
  let g:vimwiki_main = 'README'
  let g:vimwiki_auto_chdir = 1

  augroup vimwiki
      autocmd!
      au BufReadPost,BufNewFile *.md*,*.txt,*.tex setlocal autoread
      au BufReadPost,BufNewFile *.md*,*.txt,*.tex ScrollbarHide
      au BufReadPost,BufNewFile *.md*,*.txt,*.tex Gitsigns detach
  augroup END


  let personal = {}
  let personal.path = "$HOME/documents/notes"

  let guides = {}
  let guides.path = '~/guides'

  let g:vimwiki_folding=''
  augroup vimwiki_gutter_disable
    autocmd!
    autocmd FileType vimwiki setlocal signcolumn=no
    autocmd FileType vimwiki setlocal foldcolumn=0
  augroup END

  let g:vimwiki_list = [personal,guides]
  let g:vimwiki_ext2syntax = {
    \ '.md': 'markdown',
    \ '.markdown': 'markdown',
    \ '.mdown': 'markdown'
    \ }
]])
