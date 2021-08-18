" The MIT License (MIT)
"
" Copyright (c) 2020 Urbain Vaes
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

if exists('g:loaded_ripple') || &compatible
    finish
endif
let g:loaded_ripple = 1

let s:default_enable_mappings = 1

nnoremap <silent> <Plug>(ripple_open_repl) :call ripple#open_repl(1)<cr>
nnoremap <silent> <expr> <Plug>(ripple_send_motion) ripple#send_motion()
nnoremap <silent> <Plug>(ripple_send_previous) :<c-u>call ripple#send_previous()<cr>
nnoremap <silent> <Plug>(ripple_send_buffer) :<c-u>call ripple#send_buffer()<cr>
xnoremap <silent> <Plug>(ripple_send_selection) :<c-u>call ripple#send_visual()<cr>
nmap <silent> <Plug>(ripple_send_line) <Plug>(ripple_send_motion)_
nnoremap <Plug>(ripple_link_term) :RippleLink term

if get(g:, 'ripple_enable_mappings', s:default_enable_mappings)
    nmap y<cr> <Plug>(ripple_open_repl)
    nmap yr <Plug>(ripple_send_motion)
    nmap yr<cr> <Plug>(ripple_send_buffer)
    nmap yrr <Plug>(ripple_send_line)
    nmap yp <Plug>(ripple_send_previous)
    xmap R <Plug>(ripple_send_selection)
    nmap yrL <Plug>(ripple_link_term)

    nmap 1yr "1yr
    nmap 1yrr "1yrr
endif

command! -range -nargs=* Ripple call ripple#command(<line1>, <line2>, <q-args>)
command! -complete=buffer -nargs=1 RippleLink call ripple#link_term(<q-args>)
