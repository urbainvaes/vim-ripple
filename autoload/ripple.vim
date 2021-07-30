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
let s:default_term_name = "term: ripple"
let s:default_always_return = 0

function! s:remove_comments(code)
    return substitute(a:code, "^#[^\r]*\r\\|\r#[^\r]*", "", "g")
endfunction

let s:default_repls = {
            \ "python": {
                \ "command": "ipython",
                \ "pre": "\<esc>[200~",
                \ "post": "\<esc>[201~",
                \ "addcr": 0,
                \ "filter": 0,
                \ },
            \ "julia": "julia",
            \ "lua": "lua",
            \ "r": "R",
            \ "ruby": "irb",
            \ "scheme": "guile",
            \ "sh": "bash",
            \ "zsh": {
                \ "command": "zsh",
                \ "filter": function('s:remove_comments'),
                \ }
            \ }

" Memory for the state of the plugin
let s:sources = {}
let s:repl_params = {}
let s:buf_to_term = {}
let s:ft_to_term = {}

" Last used source
let s:source = ""

function! s:echo(string)
    echohl Type
    echon "vim-ripple: "
    echohl None
    echon a:string
    echon "\<cr>"
endfunction

function! ripple#status()
    let [bufn, ft] = [bufnr('%'), &ft]
    if !has_key(s:buf_to_term, bufn)
        call s:echo("Buffer is not paired to any terminal yet…")
    elseif s:is_isolated()
        call s:echo("Buffer is paired with isolated REPL in buffer number ".s:buf_to_term[bufn].".")
    else
        call s:echo("Buffer is paired with shared ".ft." REPL in buffer number ".s:buf_to_term[bufn].".")
    endif
    echom s:repl_params[&ft]
endfunction

function! s:set_repl_params()
    " FIXME: The keys of s:repl_params should probably be buffers instead of
    " filetypes… Also, the presence of this buffer variable should force a
    " separate REPL.
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
        let repl = {"command": repl}
    endif

    " Legacy
    if type(repl) == 3
        let repl = {
                    \ "command": repl[0],
                    \ "pre": repl[1],
                    \ "post": repl[2],
                    \ "addcr": repl[3],
                    \ "filter": len(repl) > 4 ? repl[4] : 0
                    \ }
    endif

    let params = {"pre": "", "post": "", "addcr": 0, "filter": 0}
    call extend(params, repl)

    let s:repl_params[&ft] = params
    return 0
endfunction

function! s:is_isolated()
    let [bufn, ft] = [bufnr('%'), &ft]

    " If term opened
    if has_key(s:buf_to_term, bufn)
        if !has_key(s:ft_to_term, ft)
            return 1
        elseif s:ft_to_term[ft] != s:buf_to_term[bufn]
            return 1
        else
            return 0
        endif
    endif

    " If term not opened
    if has_key(b:, 'ripple_term_name') || has_key(b:, 'ripple_repl')
        return 1
    else
        return 0
    endif
endfunction

function! s:assign_repl()
    if has_key(b:, 'ripple_term_name') || has_key(b:, 'ripple_repl')
        return ripple#open_repl(1)
    endif

    let [bufn, ft] = [bufnr('%'), &ft]
    if has_key(s:ft_to_term, ft) && bufexists(s:ft_to_term[ft])
            \ && (has('nvim') || term_getstatus(s:buf_to_term[bufn]) != "finished")
        let s:buf_to_term[bufn] = s:ft_to_term[ft]
        return 0
    endif
    return ripple#open_repl(0)
endfunction

function! ripple#open_repl(isolated)
    let [bufn, ft] = [bufnr('%'), &ft]

    if a:isolated
        echohl Type
        echon "vim-ripple: "
        echohl None
        echon "Opening an isolated REPL. To open a REPL common to all buffers of filetype '"
        echohl Identifier
        echon ft
        echohl None
        echon "', use '"
        echohl Identifier
        echon "yr<motion>"
        echohl None
        echon "' directly.\<cr>"
    endif

    let winid = win_getid()
    if s:set_repl_params() == -1
        return -1
    endif

    let legacy = 'no'
    if has_key(g:, 'ripple_window')
        let legacy = 'g:ripple_window'
    elseif has_key(g:, 'ripple_term_command')
        let legacy = 'g:ripple_term_command'
    endif
    if legacy == 'no'
        let winpos = get(g:, 'ripple_winpos', s:default_winpos)

        let term_name = ""
        if has_key(b:, 'ripple_term_name')
            let term_name = b:ripple_term_name
        else
            let term_name = get(g:, 'ripple_term_name', s:default_term_name)
            if a:isolated
                let term_name = term_name."_".ft."_b".bufn
            else
                let term_name = term_name."_".ft."_common"
            endif
        endif

        if bufexists(term_name)
            echom "Buffer '".term_name."' already exists…"
            return -1
        endif

        if has_key(g:, 'ripple_winexpr')
          silent execute winpos.eval(g:ripple_winexpr)." new"
        else
          silent execute winpos." new"
        endif

        if has("nvim")
            silent execute "term" s:repl_params[ft]["command"]
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
            silent call term_start(s:repl_params[ft]["command"], term_options)
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
            silent execute "term" s:repl_params[ft]["command"]
        else
            let term_command = get(g:, 'ripple_term_command', s:default_term_command)
            silent execute term_command s:repl_params[ft]["command"]
        endif
    endif

    if has("nvim")
        " Move cursor to last line to follow output
        norm G
        if &runtimepath =~ 'vim-tmux-pilot'
            call pilot#autoinsert()
        endif
    endif

    let term_buf = bufnr('%')
    call win_gotoid(winid)

    let delay = get(g:, 'ripple_delay', s:default_delay)
    execute "sleep" delay

    let s:buf_to_term[bufn] = term_buf
    if !a:isolated
       let s:ft_to_term[ft] = term_buf
    endif
    return 0
endfunction

function! s:send_to_buffer(formatted)
    let [ft, bufn] = [&ft, bufnr('%')]
    if !has_key(s:buf_to_term, bufn)
        echom "No term buffer opened for buffer '".bufn."'…"
        return -1
    endif
    let tabnr = tabpagenr()
    tab split
    " Silent for vim
    silent execute "noautocmd buffer" s:buf_to_term[bufn]
    norm G$
    if has("nvim")
        if s:repl_params[ft]["command"] == "radian"
            put =a:formatted
        else
            call chansend(getbufvar("%", '&channel'), a:formatted)
        end
    else
        let typed_string = "\<c-\>\<c-n>a".a:formatted
        call feedkeys(typed_string, "ntx")
    endif
    tab close
    noautocmd execute 'tabnext' tabnr
endfunction

function! s:send_code(...)
    let bufn = bufnr('%')
    if !has_key(s:buf_to_term, bufn) || !buffer_exists(s:buf_to_term[bufn])
                \ || (!has('nvim') && term_getstatus(s:buf_to_term[bufn]) == "finished")
        if s:assign_repl() == -1
            return
        endif
    endif

    if a:0 == 0
        " Add <cr> (useful e.g. so that python functions get run)
        let ft = s:source['ft']
        let code = s:extract_code()
        let code = (s:is_end_paragraph() && s:repl_params[ft]["addcr"]) ? code."\<cr>" : code
        let always_return = get(g:, "ripple_always_return", s:default_always_return)
        let newline = (s:is_charwise() && !always_return) ? "" : "\<cr>"
        if s:repl_params[ft]["filter"] != 0
            let code = s:repl_params[ft]["filter"](code)
        endif
    else
        let ft = &ft
        let code = a:1
        let newline = "\<cr>"
    endif
    let bracketed_paste = [s:repl_params[ft]["pre"], s:repl_params[ft]["post"]]
    let formatted_code = bracketed_paste[0].code.bracketed_paste[1]
    call s:send_to_buffer(formatted_code)

    " Hack for windows
    " Before, the new line was appended to `formatted_code`.
    if has_key(g:, "ripple_sleep_hack")
        redraw
        exe "sleep ".g:ripple_sleep_hack
    end
    call s:send_to_buffer(newline)
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

function! s:new_source(reg)
    let key = s:is_isolated() ? bufnr('%') : &ft
    if !has_key(s:sources, key)
        let s:sources[key] = {}
    endif
    if !has_key(s:sources[key], a:reg)
        let s:sources[key][a:reg] = []
    endif
    if len(s:sources[key][a:reg]) > 9
        call remove(s:sources[key][a:reg], -1)
    end
    call insert(s:sources[key][a:reg], {}, 0)
    return s:sources[key][a:reg][0]
endfunction

function! s:send_lines(l1, l2)
    let s:ft = &ft
    let s:source = s:new_source(v:register)
    let [s:source['mode'], s:source['ft']] = ["line", &ft]
    let [s:source['line_start'], s:source['line_end']] = [a:l1, a:l2]
    let [s:source['column_start'], s:source['column_end']] = [-1, -1]
    let s:source['bufnr'] = bufnr("%")
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
    let [myreg, mycount] = [v:register, v:count]
    let key = s:is_isolated() ? bufnr('%') : &ft

    if !has_key(s:sources, key)
        echom "No previous selection…"
        return -1
    endif
    if !has_key(s:sources[key], myreg)
        echom "Register is empty…"
        return -1
    endif
    if len(s:sources[key][myreg]) <= mycount
        echom "There are only ".len(s:sources[key][myreg])." in memory…"
        return -1
    endif
    if !buflisted(s:sources[key][myreg][mycount]['bufnr'])
        echom "Buffer no longer exists…"
        return -1
    endif

    let s:source = s:sources[key][myreg][mycount]
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_buffer()
    let reg = v:register
    let s:source = s:new_source(reg)
    let s:source["mode"] = "line"
    let s:source["ft"] = &ft
    let [s:source['line_start'], s:source['line_end']] = [1, line('$')]
    let [s:source['column_start'], s:source['column_end']] = [-1, -1]
    let s:source['bufnr'] = bufnr("%")
    call s:send_code()
    call s:highlight()
endfunction

function! ripple#send_visual()
    let reg = v:register
    let s:source = s:new_source(reg)
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
    let reg = v:register
    let s:source = s:new_source(reg)
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
