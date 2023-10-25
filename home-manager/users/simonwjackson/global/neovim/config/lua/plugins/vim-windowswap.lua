-- Swap windows without ruining your layout!

return {
	{
		"wesQ3/vim-windowswap",
		lazy = false,
		config = function()
			vim.cmd([[
    let g:windowswap_map_keys = 0 "prevent default bindings

    function! DoSwapLeft()
    call WindowSwap#MarkWindowSwap()
    wincmd h
    call WindowSwap#DoWindowSwap()
    endfunction

    function! DoSwapDown()
    call WindowSwap#MarkWindowSwap()
    wincmd j
    call WindowSwap#DoWindowSwap()
    endfunction

    function! DoSwapUp()
    call WindowSwap#MarkWindowSwap()
    wincmd k
    call WindowSwap#DoWindowSwap()
    endfunction

    function! DoSwapRight()
    call WindowSwap#MarkWindowSwap()
    wincmd l
    call WindowSwap#DoWindowSwap()
    endfunction

    nnoremap <leader>wh :call DoSwapLeft()<CR>
    nnoremap <leader>wj :call DoSwapDown()<CR>
    nnoremap <leader>wk :call DoSwapUp()<CR>
    nnoremap <leader>wl :call DoSwapRight()<CR>
    ]])
		end,
	},
}
