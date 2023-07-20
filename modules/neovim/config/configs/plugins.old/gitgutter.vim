" ----------------------------------------------------------------------------
"  - Git gutter
" ----------------------------------------------------------------------------

let g:gitgutter_enabled=1
let g:gitgutter_max_signs=2000
let g:gitgutter_preview_win_floating=1

let g:gitgutter_override_sign_column_highlight = 0
call gitgutter#highlight#define_highlights()

" highlight clear SignColumn

" Flatten all gutter icons
let g:gitgutter_sign_added = '│' " █▓▒░║
let g:gitgutter_sign_modified = '│'
let g:gitgutter_sign_removed = '▔'
let g:gitgutter_sign_removed_first_line = '▔'
let g:gitgutter_sign_modified_removed = '▔'

function! GitGutterNextHunkCycle()
    let line = line('.')
    silent! GitGutterNextHunk
    if line('.') == line
        1
        GitGutterNextHunk
    endif
endfunction


