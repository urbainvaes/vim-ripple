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

let s:default_autoinsert = 1
let s:default_highlight = "DiffAdd"
let s:default_winpos = "vertical"
let s:default_delay = "500m"
let s:default_repls = {
            \ "python": ["ipython", "\<c-u>\<esc>[200~", "\<esc>[201~", 1],
            \ "julia": "julia",
            \ "lua": "lua",
            \ "r": "R",
            \ "ruby": "irb",
            \ "scheme": "guile",
            \ "sh": "bash",
            \ "zsh": "zsh",
            \ }

" Memory for the state of the plugin
let s:term_buffer_nr = -1

function! ripple#status()
    if s:term_buffer_nr == -1
        echom "No term buffer opened…"
    else
        echom "Term buffer:" s:term_buffer_nr."."
    endif
endfunction

function! s:set_repl_params()
    let repls = deepcopy(s:default_repls)
    if has_key(g:, 'ripple_repls')
        call extend(repls, g:ripple_repls)
    endif
    if has_key(b:, 'ripple_repl')
        let repl = b:ripple_repl
    elseif has_key(repls, &ft)
        let repl = repls[&ft]
    else
        echom "No repl for filetype '".&ft."'…"
        return -1
    endif
    if type(repl) == 1
        let repl = [repl, "", "", 0]
    endif

    let s:repl_params = repl
    return 0
endfunction

function! ripple#open_repl()
    if s:term_buffer_nr != -1 && buffer_exists(s:term_buffer_nr)
        return
    endif
    let winid = win_getid()

    if s:set_repl_params() == -1
        return -1
    endif

    let legacy = 'no'
    if has_key(g:, 'ripple_window')
        let legacy = 'g:ripple_window'
    elseif has_key(g:, 'ripple_term_command')
        let legacy = 'ripple_term_command'
    endif
    if legacy == 'no'
        let winpos = get(g:, 'ripple_winpos', s:default_winpos)
        if has("nvim")
            silent execute winpos." new"
            silent execute "term" s:repl_params[0]
        else
            silent execute winpos." term ".s:repl_params[0]
        endif
    else
        " Legacy code
        echohl Type
        echon "vim-ripple: "
        echohl Identifier
        echon "'".legacy."'"
        echohl None
        echon " is deprecated; use "
        echohl Identifier
        echon "'g:ripple_winpos'"
        echohl None
        echon " instead.\<cr>"

        let s:default_window = "vnew"
        let s:default_term_command = "vertical terminal"
        if has("nvim")
            let new_window = get(g:, 'ripple_window', s:default_window)
            silent execute new_window
            silent execute "term" s:repl_params[0]
        else
            let term_command = get(g:, 'ripple_term_command', s:default_term_command)
            silent execute term_command s:repl_params[0]
        endif
    endif
    let s:term_buffer_nr = bufnr('%')

    if has("nvim")
        " Move cursor to last line to follow output
        norm G
        if &runtimepath =~ 'vim-tmux-pilot'
            call pilot#autoinsert()
        endif
    endif

    call win_gotoid(winid)
    execute "sleep" s:default_delay
    return 0
endfunction

function! s:send_to_buffer(formatted)
    let tabnr = tabpagenr()
    tab split
    " Silent for vim
    silent execute "noautocmd buffer" s:term_buffer_nr
    norm G$
    if has("nvim")
        put =a:formatted
    else
        let typed_string = "\<c-\>\<c-n>a".a:formatted
        call feedkeys(typed_string, "ntx")
    endif
    tab close
    noautocmd execute 'tabnext' tabnr
endfunction

function! s:send_code(...)
    " We need this here because this sets repl_params
    if ripple#open_repl() == -1
        return
    endif

    if a:0 == 0
        " Sometimes, for example with the motion `}`, the line where the cursor
        " lands is not included, which is often undesirable for this plugin.
        " For example, without an extra <cr>, running `yr}` on a Python function
        " with an empty line after it will paste the code of the function but not
        " execute it.
        let code = join(s:lines(), "\<cr>")

        " Add <cr> (useful e.g. so that python functions get run)
        let code = (s:is_end_paragraph() && s:repl_params[3]) ? code."\<cr>" : code
        let newline = s:is_charwise() ? "" : "\<cr>"
    else
        let code = a:1
        let newline = "\<cr>"
    endif
    let bracketed_paste = [s:repl_params[1], s:repl_params[2]]
    let formatted_code = bracketed_paste[0].code.bracketed_paste[1].newline
    call s:send_to_buffer(formatted_code)
endfunction

function! s:highlight()
    let higroup = get(g:, 'ripple_highlight', s:default_highlight)
    if &runtimepath =~ 'highlightedyank' && higroup != ""
        let start = [0, s:line_start, s:column_start, 0]
        let end = [0, s:line_end, s:column_end, 0]
        let type = s:is_charwise() ? 'v' : 'V'
        let delay = 1000
        call highlightedyank#highlight#add(higroup, start, end, type, delay)
    endif
endfunction

function! ripple#send_previous()
    if s:term_buffer_nr == -1
        echom "No term buffer opened…"
        return
    elseif !has_key(s:, 'line_start')
        echom "No previous selection…"
        return
    endif
    call s:send_code()
    call s:highlight()
endfunction

function! s:is_charwise()
    return (s:mode ==# "char" || s:mode ==# "v")
endfunction

function! s:is_end_paragraph()
    return s:mode == "line"
                \ && getline(s:line_end) != ""
                \ && getline(s:line_end + 1) == ""
endfunction

function! s:lines()
    let lines = getline(s:line_start, s:line_end)
    if s:is_charwise() && len(lines) > 0
        let lines[-1] = lines[-1][:s:column_end - 1]
        let lines[0] = lines[0][s:column_start - 1:]
    endif
    return lines
endfunction

function! s:update_state()
    let is_visual = (s:mode ==# "v" || s:mode ==# "V")
    let m1 = is_visual ? "'<" : "'["
    let m2 = is_visual ? "'>" : "']"
    let [s:line_start, s:column_start] = getpos(l:m1)[1:2]
    let [s:line_end, s:column_end] = getpos(l:m2)[1:2]

    if s:is_charwise() && is_visual && &selection=='exclusive'
        let s:column_end = s:column_end - 1
    endif
endfunction

function! ripple#command(l1, l2, text)
    if a:text != ""
        call s:send_code(a:text)
    else
        call s:send_lines(a:l1, a:l2)
    endif
endfunction

function! s:send_lines(l1, l2)
    let s:mode = "line"
    let [s:line_start, s:line_end] = [a:l1, a:l2]
    let [s:column_start, s:column_end] = [-1, -1]
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_buffer()
    let s:mode = "line"
    let [s:line_start, s:line_end] = [1, line('$')]
    let [s:column_start, s:column_end] = [-1, -1]
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_visual()
    let s:mode = visualmode()
    call s:update_state()
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#accept_motion(...)
    let s:mode = a:1
    call s:update_state()
    call s:send_code()
    call s:highlight()
    call setpos('.', s:save_cursor)
    call winrestview(s:save_view)
endfunction

function! ripple#send_motion()
    let s:save_cursor = getcurpos()
    let s:save_view = winsaveview()
    set operatorfunc=ripple#accept_motion
    return 'g@'
endfunction
