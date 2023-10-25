-- Personal wiki for Vim – interlinked, plain text files written in markdownish syntax.

local g = vim.g

return {
	{
		"vimwiki/vimwiki",
		lazy = false,
		init = function()
			g.vimwiki_global_ext = 0
			g.vimwiki_markdown_link_ext = 1
			g.vimwiki_links_space_char = "-"
			g.vimwiki_autowriteall = 1
			g.vimwiki_syntax = "markdown"
			g.vimwiki_ext = ".md"
			g.vimwiki_main = "README"
			g.vimwiki_auto_chdir = 1
			g.vimwiki_folding = ""

			vim.cmd([[

    let notes = {}
    let notes.path = "$HOME/documents/notes"

    let g:vimwiki_list = [notes]
    let g:vimwiki_ext2syntax = {
      \ '.md': 'markdown',
      \ '.markdown': 'markdown',
      \ '.mdown': 'markdown'
      \ }
      ]])
		end,
	},
}
