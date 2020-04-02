" The MIT License (MIT)
"
" Copyright (c) 2018 Urbain Vaes
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

let s:default_highlight = "DiffAdd"
let s:default_window = "vnew"
let s:default_term_command = "vertical terminal"
let s:default_delay = "1000m"
let s:default_repls = {
            \ "python": ["ipython", "\<c-u>\<esc>[200~", "\<esc>[201~", 1],
            \ "scheme": "guile",
            \ "sh": "bash"
            \ }

function! ripple#status()
    if s:term_buffer_nr == -1
        echom "No term buffer opened"
    else
        echom "Term buffer:" s:term_buffer_nr
    endif
endfunction

function! ripple#open_repl()
    if s:term_buffer_nr != -1 && buffer_exists(s:term_buffer_nr)
        return
    endif
    let [ft, winnr] = [&ft, winnr()]

    let repls = s:default_repls
    if has_key(g:, 'ripple_repls')
        call extend(repls, g:ripple_repls)
    endif
    if has_key(repls, ft)
        let s:repl_params = repls[ft]
    else
        echom "No repl for filetype" ft
        return -1
    endif

    if type(s:repl_params) == 1  " If string
        let s:repl_params = [s:repl_params, "", "", 0]
    endif

    if has("nvim")
        let new_window = get(g:, 'ripple_window', s:default_window)
        silent execute new_window
        silent execute "term" s:repl_params[0]
    else
        let term_command = get(g:, 'ripple_term_command', s:default_term_command)
        silent execute term_command s:repl_params[0]
    endif
    let s:term_buffer_nr = bufnr()

    execute winnr."wincmd w"
    execute "sleep" s:default_delay
    return 0
endfunction

function! s:send_to_term(code, newline, add_cr)
    let return_code = ripple#open_repl()
    if return_code == -1
        return
    endif

    " Add <cr> (useful e.g. so that python functions get run)
    let code = (a:add_cr && s:repl_params[3]) ? a:code."\<cr>" : a:code
    tab split
    execute "noautocmd buffer" s:term_buffer_nr
    norm G$
    if has("nvim")
        let open_bracketed_paste = s:repl_params[1]
        let close_bracketed_paste = s:repl_params[2]
        put =open_bracketed_paste
        put =code
        put =close_bracketed_paste
        if a:newline
            let newline = "\<cr>"
            put =newline
        endif
    else
        let open_bracketed_paste = s:repl_params[1]
        let close_bracketed_paste = s:repl_params[2]
        let newline = a:newline ? "\<cr>" : ""
        let typed_string = "\<c-\>\<c-n>a".open_bracketed_paste.code.close_bracketed_paste.newline
        call feedkeys(typed_string, "ntx")
    endif
    tab close
endfunction

" Memory to execute previous code selection
let s:term_buffer_nr = -1
let s:is_visual = 0
let s:charwise = 1
let s:repl_params = []
let [s:line_start, s:column_start] = [0, 0]
let [s:line_end, s:column_end] = [0, 0]
let s:end_paragraph = 0
let s:end_file = 0

" Argument is either
" - "p": to repeat previous code selection
" - "v" or "V": when called from v or V mode
" - "line" or "char", when called from g@
function! ripple#send_motion_or_selection(...)
    if a:1 != "p"
        let s:is_visual = (a:1 ==# "v" || a:1 ==# "V")
        let s:char_wise = (a:1 ==# "char" || a:1 ==# "v")
        let m1 = s:is_visual ? "'<" : "'["
        let m2 = s:is_visual ? "'>" : "']"
        let [s:line_start, s:column_start] = getpos(l:m1)[1:2]
        let [s:line_end, s:column_end] = getpos(l:m2)[1:2]

        let s:end_paragraph = a:1 == "line"
                    \ && getline(s:line_end) != ""
                    \ && getline(s:line_end + 1) == ""
        " To handle `yr}` at the endo of file
        let s:end_file = a:1 == "char"
                    \ && s:line_end == line('$')
                    \ && s:column_end == strlen(getline(s:line_end))
    endif

    let lines = getline(s:line_start, s:line_end)
    if s:char_wise
        let offset = (&selection == 'inclusive' ? 1 : 2)
        let lines[-1] = lines[-1][:s:column_end - offset]
        let lines[0] = lines[0][s:column_start - 1:]
    endif

    " Sometimes, for example with motion `}`, the line where the cursor
    " lands is not included, which is often undesirable for this plugin.
    " For example, running `yr}` on a Python function with an empty line
    " after it will paste the code of the function but not execute it.

    let add_cr = s:end_paragraph || s:end_file
    let code = join(lines, "\<cr>")
    let newline = s:end_file || !s:char_wise
    call s:send_to_term(code, newline, add_cr)

    if a:1 == "line" || a:1 == "char"
        call setpos('.', s:save_cursor)
        call winrestview(s:save_view)
    endif

    let higroup = get(g:, 'ripple_highlight', s:default_highlight)
    if &runtimepath =~ 'highlightedyank' && higroup != ""
        let start = [0, s:line_start, s:column_start, 0]
        let end = [0, s:line_end, s:column_end, 0]
        let type = s:char_wise ? 'v' : 'V'
        let delay = 1000
        call highlightedyank#highlight#add(higroup, start, end, type, delay)
    endif
endfunction

function! ripple#send_motion()
    let s:save_cursor = getcurpos()
    let s:save_view = winsaveview()
    set operatorfunc=ripple#send_motion_or_selection
    return 'g@'
endfunction
