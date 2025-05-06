set nocompatible

" remap key
" insert mode
inoremap kj <Esc>
" Visual mode
vnoremap kj <Esc> 
" normal mode
nnoremap <F4> :set invrnu!<CR>
nnoremap crf :let @" = expand("%")<CR>
nnoremap cff :let @" = expand("%:p")<CR>
nnoremap tt :7<CR>VG$:!sort -nk2<CR>
" ruler
set nu rnu

" style setting
set ruler
set colorcolumn=80
highlight ColorColumn ctermbg=5
set t_Co=256
