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
let s:default_one_term_per = "buf"

function! s:remove_comments(code)
    return substitute(a:code, "^#[^\r]*\r\\|\r#[^\r]*", "", "g")
endfunction

let s:default_repls = {
            \ "python": ["ipython", "\<c-u>\<esc>[200~", "\<esc>[201~", 1],
            \ "julia": "julia",
            \ "lua": "lua",
            \ "r": "R",
            \ "ruby": "irb",
            \ "scheme": "guile",
            \ "sh": "bash",
            \ "zsh": ["zsh", "", "", 0, function('s:remove_comments')],
            \ }

" Memory for the state of the plugin
let s:sources = {}
let s:term_buffer_nr = {}
let s:repl_params = {}

" Last used source
let s:source = ""

function! ripple#status()
    let config = get(g:, 'ripple_one_term_per', s:default_one_term_per)
    if config =~ "^f" && !has_key(s:term_buffer_nr, &ft)
        echom "No term buffer opened for filetype '".&ft."'…"
    elseif config =~ "^b" && !has_key(s:term_buffer_nr, bufnr())
        echom "No term buffer opened for buffer '".bufnr()."'…"
    else
        echom "Term buffer:" s:term_buffer_nr[s:get_key()]."."
    endif
endfunction

function! s:get_key()
    let config = get(g:, 'ripple_one_term_per', s:default_one_term_per)
    return config =~ "^f" ? &ft : bufnr()
endfunction

function! s:set_repl_params()
    if has_key(b:, 'ripple_repl')
        let repl = b:ripple_repl
    else
        let repls = deepcopy(s:default_repls)
        if has_key(g:, 'ripple_repls')
            call extend(repls, g:ripple_repls)
        endif
        if has_key(repls, &ft)
            let repl = repls[&ft]
        else
            echom "No repl for filetype '".&ft."'…"
            return -1
        endif
    if type(repl) == 1
        let repl = [repl, "", "", 0]
    endif
    let s:repl_params[&ft] = repl
    return 0
endfunction

function! ripple#open_repl()
    let [ft, key] = [&ft, s:get_key()]
    if has_key(s:term_buffer_nr, key) && buffer_exists(s:term_buffer_nr[key])
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

        let term_name = ""
        if has_key(b:, 'ripple_term_name')
            let term_name = b:ripple_term_name
        elseif has_key(g:, 'ripple_term_name_root')
            let term_name = g:ripple_term_name_root."_".&ft
        elseif has_key(g:, 'ripple_term_name')
            let term_name = g:ripple_term_name
            if bufexists(term_name)
                echom "Buffer '".term_name."' already exists, appending _".&ft."…"
                let term_name = term_name."_".&ft
            endif
        endif

        silent execute winpos." new"
        if has("nvim")
            silent execute "term" s:repl_params[ft][0]
            if term_name != ""
                exec "file ".term_name
            endif
        else
            let term_options = {"curwin": 1}
            if term_name != ""
                let term_options["term_name"] = term_name
            endif
            if has_key(g:, 'ripple_term_options')
                call extend(term_options, g:ripple_term_options)
            endif
            silent call term_start(s:repl_params[ft][0], term_options)
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
            silent execute "term" s:repl_params[ft][0]
        else
            let term_command = get(g:, 'ripple_term_command', s:default_term_command)
            silent execute term_command s:repl_params[ft][0]
        endif
    endif
    let s:term_buffer_nr[key] = bufnr('%')

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
    let key = s:get_key()
    if !has_key(s:term_buffer_nr, key)
        echom "No term buffer opened for key '".key."'…"
        return —1
    endif
    let tabnr = tabpagenr()
    tab split
    " Silent for vim
    silent execute "noautocmd buffer" s:term_buffer_nr[key]
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
        " Add <cr> (useful e.g. so that python functions get run)
        let ft = s:source['ft']
        let code = s:extract_code()
        let code = (s:is_end_paragraph() && s:repl_params[ft][3]) ? code."\<cr>" : code
        let newline = s:is_charwise() ? "" : "\<cr>"
        if len(s:repl_params[ft]) == 5
            let code = s:repl_params[ft][4](code)
        endif
    else
        let code = a:1
        let newline = "\<cr>"
    endif
    let bracketed_paste = [s:repl_params[ft][1], s:repl_params[ft][2]]
    let formatted_code = bracketed_paste[0].code.bracketed_paste[1].newline
    call s:send_to_buffer(formatted_code)
endfunction

function! s:is_charwise()
    let mode = s:source['mode']
    return (mode ==# "char" || mode ==# "v")
endfunction

function! s:is_end_paragraph()
    return s:source['mode'] == "line"
                \ && getline(s:source['line_end']) != ""
                \ && getline(s:source['line_end'] + 1) == ""
endfunction

function! s:extract_code()
    let lines = getbufline(s:source['bufnr'], s:source['line_start'], s:source['line_end'])
    if s:is_charwise() && len(lines) > -1
        let lines[-1] = lines[-1][:s:source['column_end'] - 1]
        let lines[0] = lines[0][s:source['column_start'] - 1:]
    endif
    " Sometimes, for example with the motion `}`, the line where the cursor
    " lands is not included, which is often undesirable for this plugin.
    " For example, without an extra <cr>, running `yr}` on a Python function
    " with an empty line after it will paste the code of the function but not
    " execute it.
    if empty(lines)
        return
    endif
    let code = join(lines, "\<cr>")
    return code
endfunction

function! s:highlight()
    if bufnr("%") != s:source['bufnr']
        return
    endif
    let higroup = get(g:, 'ripple_highlight', s:default_highlight)
    if &runtimepath =~ 'highlightedyank' && higroup != ""
        let start = [0, s:source['line_start'], s:source['column_start'], 0]
        let end = [0, s:source['line_end'], s:source['column_end'], 0]
        let type = s:is_charwise() ? 'v' : 'V'
        let delay = 1000
        call highlightedyank#highlight#add(higroup, start, end, type, delay)
    endif
endfunction

function! s:new_source(index)
    let key = s:get_key()
    if !has_key(s:sources, key)
        let s:sources[key] = {}
    endif
    let s:sources[key][a:index] = {}
    return s:sources[key][a:index]
endfunction

function! s:send_lines(l1, l2)
    let s:ft = &ft
    let source = s:new_source(0)
    let source['mode'] = "line"
    let [source['line_start'], source['line_end']] = [a:l1, a:l2]
    let [source['column_start'], source['column_end']] = [-1, -1]
    let source['bufnr'] = bufnr("%")
    call s:send_code()
    call s:highlight()
endfunction

function! s:extract_source()
    let is_visual = (s:source['mode'] ==# "v" || s:source['mode'] ==# "V")
    let m1 = is_visual ? "'<" : "'["
    let m2 = is_visual ? "'>" : "']"
    let [s:source['line_start'], s:source['column_start']] = getpos(l:m1)[1:2]
    let [s:source['line_end'], s:source['column_end']] = getpos(l:m2)[1:2]
    let s:source['bufnr'] = bufnr("%")
    if s:is_charwise() && is_visual && &selection=='exclusive'
        let s:source['column_end'] = s:source['column_end'] - 1
    endif
endfunction

function! ripple#command(l1, l2, text)
    if a:text != ""
        call s:send_code(a:text)
    else
        call s:send_lines(a:l1, a:l2)
    endif
endfunction

function! ripple#send_previous()
    let index = v:register =~ "[0-9]" ? v:register : 0
    let config = get(g:, 'ripple_one_term_per', s:default_one_term_per)
    if config =~ "^f" && !has_key(s:term_buffer_nr, &ft)
        echom "No term buffer opened for filetype '".&ft."'…"
        return -1
    elseif config =~ "^f" && !has_key(s:sources, &ft)
        echom "No previous selection for filetype '".&ft."'…"
        return -1
    elseif config =~ "^b" && !has_key(s:term_buffer_nr, bufnr())
        echom "No term buffer opened for buffer '".bufnr()."'…"
        return -1
    elseif config =~ "^b" && !has_key(s:sources, bufnr())
        echom "No previous selection for buffer '".bufnr()."'…"
        return -1
    endif
    let key = config == "ft" ? &ft : bufnr()
    if !has_key(s:sources[key], index)
        echom "Register is empty…"
        return -1
    elseif !buflisted(s:sources[key][index]['bufnr'])
        echom "Buffer no longer exists…"
        return -1
    endif
    let s:source = s:sources[key][index]
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_buffer()
    let index = v:register =~ "[0-9]" ? v:register : 0
    let s:source = s:new_source(index)
    let s:source["mode"] = "line"
    let s:source["ft"] = &ft
    let [s:source['line_start'], s:source['line_end']] = [1, line('$')]
    let [s:source['column_start'], s:source['column_end']] = [-1, -1]
    let s:source['bufnr'] = bufnr("%")
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_visual()
    let index = v:register =~ "[0-9]" ? v:register : 0
    let s:source = s:new_source(index)
    let s:source['mode'] = visualmode()
    let s:source['ft'] = &ft
    call s:extract_source()
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#save()
    let s:save_cursor = getcurpos()
    let s:save_view = winsaveview()
endfunction

function! ripple#accept_motion(...)
    let index = v:register =~ "[0-9]" ? v:register : 0
    let s:source = s:new_source(index)
    let s:source['mode'] = a:1
    let s:source['ft'] = &ft
    call s:extract_source()
    call s:send_code()
    call s:highlight()
    call setpos('.', s:save_cursor)
    call winrestview(s:save_view)
    silent! call repeat#set(":\<c-u>call ripple#save() \<bar> norm! .\<cr>", v:count)
endfunction

function! ripple#send_motion()
    call ripple#save()
    set operatorfunc=ripple#accept_motion
    return 'g@'
endfunction
