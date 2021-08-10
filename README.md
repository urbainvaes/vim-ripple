# Ripple

This thin plugin makes it easy to send code to a REPL (read-evaluate-print loop) running within `vim` or `nvim`.
Some advantages of this plugin over some of the alternatives (such as [iron.nvim](https://github.com/Vigemus/iron.nvim)) are the following:

- This plugin is written and can be configured fully in `viml`.

- The cursor does not move when a code chunk is sent to the REPL.

- If [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed,
motions sent to the REPL are highlighted.

- If not explicitly opened by `y<cr>`,
the REPL opens automatically once a code chunk is sent.

- The plugin is compatible with Tim Pope's [vim-repeat](https://github.com/tpope/vim-repeat).

- Previous code selections are saved and can be reused easily (see `yp` in the documentation).

![](https://raw.github.com/urbainvaes/vim-ripple/demo/demo.gif)
(Click to enlarge.)

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'urbainvaes/vim-ripple'

" OPTIONAL DEPENDENCIES

" Highlight code chunks sent to REPL
Plug 'machakann/vim-highlightedyank'

" Streamline navigation (e.g. autoinsert in terminal)
Plug 'urbainvaes/vim-tmux-pilot'
```

## Configuration of the REPLs

New REPLs can be defined in the dictionary `g:ripple_repls`.
These definitions take precedence over the default REPLs defined in the plugin,
which are listed below.
In the dictionary, the keys are `filetype`s
and the values are dictionaries specifying options of the REPL.
The entries that each of these dictionaries can contain are given in the following table:

| Keys      | Default values (except for **Python**) | Description                 |
| ----      | -------------------------------------- | -----------                 |
| `command` | Mandatory argument                     | String                      |
| `pre`     | `""`                                   | String                      |
| `post`    | `""`                                   | String                      |
| `addcr`   | `0`                                    | Boolean (`0` or `1`)        |
| `filter`  | `{x -> x}` (no effect)                 | `0` or a function reference |

- The mandatory key `command` contains the command to start the REPL (e.g. `julia`, `guile`, `bash`).

- The parameters `pre` and `post` contain strings to prepend and append to code sent to the REPL,
  respectively.
  This is sometimes necessary to enable sending several lines of code to the REPL at once
  (see Python example below).

- The parameter `addcr` controls whether an additional `<cr>` should be appended to the code chunks that are followed by a blank line.
  (This can be useful to avoid the need to press `<cr>` manually in the terminal window.
  In `ipython`, for example, two `<cr>` are required to run an indented block.)

- Finally, the parameter `filter` is a function employed to format the code before sending it to the REPL.
  For example, this is used in the default settings for removing comments from `zsh` code chunks,
  which is useful because comments are not allowed in interactive shells by default
  (this can be changed using `setopt interactivecomments`).

The default configuration for `python` can be reproduced by the following lines in `.vimrc`:

```vim
let g:ripple_repls = {}
let g:ripple_repls["python"] = {
    \ "command": "ipython",
    \ "pre": "\<c-u>\<esc>[200~",
    \ "post": "\<esc>[201~",
    \ "addcr": 1,
    \ },
```

If one wishes the plugin to work with indented code,
for example in a `main()` function,
one may add a filter as follows :

```vim
function! Remove_leading_whitespaces(code)
    " Check if the first line is indented
    let leading_spaces = matchstr(a:code, '^\s\+')

    if leading_spaces == ""
        return a:code
    endif

    " Calculate indentation
    let indentation = strlen(leading_spaces)

    " Remove further indentations
    return substitute(a:code, '\(^\|\r\zs\)\s\{'.indentation.'}', "", "g")
endfunction

" Add filter to REPL configuration
let g:ripple_repls["python"]["filter"] = function('Remove_leading_whitespaces')
```
This filter is not enabled by default,
but it is implemented in the plugin by the function `ripple#remove_leading_whitespaces`,
which you can use in the REPL configuration.
Currently only the following languages have default configurations:
*Python*, *Julia*, *Lua*, *R*, *Ruby*, *Scheme*, *Sh* and *Zsh*.
Feel free to open a pull request to add support for other languages.

## Mappings

The functions are exposed via `<Plug>` mappings.
If `g:ripple_enable_mappings` is set to `1`,
then additional mappings to keys are defined as follows:

| `<Plug>` Mapping                | Default key mapping | Description                    |
| -----------------------------   | ------------------- | -----------                    |
| `<Plug>(ripple_open_repl)`      | `y<cr>` (`nmap`)    | Open REPL                      |
| `<Plug>(ripple_send_motion)`    | `yr` (`nmap`)       | Send motion to REPL            |
| `<Plug>(ripple_send_previous)`  | `yp` (`nmap`)       | Resend previous code selection |
| `<Plug>(ripple_send_selection)` | `R` (`xmap`)        | Send selection to REPL         |
| `<Plug>(ripple_send_line)`      | `yrr` (`nmap`)      | Send line to REPL              |
| `<Plug>(ripple_send_buffer)`    | `yr<cr>` (`nmap`)   | Send whole buffer to REPL      |

If `<Plug>(ripple_send_motion)` is issued but no REPL is open,
a REPL will open automatically.
A mnemonic for `yr` is *you run*.
Counts and registers can be passed to `yp` in order to refer to code selections other than the last;
see the documentation for details.

## Additional customization

| Config                     | Default      | Description                          |
| ------                     | -------      | -----------                          |
| `g:ripple_winpos`          | `"vertical"` | Window position                      |
| `g:ripple_term_name`       | undefined    | Name of the terminal buffer          |
| `g:ripple_enable_mappings` | `1`          | Whether to enable default mappings   |
| `g:ripple_highlight`       | `"DiffAdd"`  | Highlight group                      |
| `g:ripple_always_return`   | `0`          | Add `<cr>` even for charwise motions |

The options `g:ripple_winpos` is the modifier to prepend to `new` (in `nvim`) or `term` (in `vim`) when opening the REPL window.
To disable the highlighting of code chunks sent to the REPL, simply `let g:ripple_highlight = ""`.
Highlighting works only when the plugin [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed.
For more information, see

```vim
:help ripple
```

## License

MIT
