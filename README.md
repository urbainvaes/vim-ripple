# Ripple

This thin plugin makes it easy to send code to a REPL (read-evaluate-print loop) running within `vim` or `nvim`.
Some advantages of this plugin over some of the alternatives (such as [iron.nvim](https://github.com/Vigemus/iron.nvim)) are the following:

- This plugin is written and can be configured in `viml`.

- The cursor does not move when a code chunk is sent to the REPL.

- If [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed,
motions sent to the REPL are highlighted.

- If not explicitly opened by `<Plug>(ripple_open_repl)`,
the REPL opens automatically once a code chunk is sent.

![](https://raw.github.com/urbainvaes/vim-ripple/demo/demo.gif)
(Click to enlarge.)

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'urbainvaes/vim-ripple'

" Optional dependency
Plug 'machakann/vim-highlightedyank'
```

## Configuration of the REPLs

New REPLs can be defined in the dictionary `g:ripple_repls`.
These definitions take precedence over the default REPLs defined in the plugin,
which are listed below.
In the dictionary, the keys are `filetype`s
and the values are either of the following:

- A string containing the command to start the REPL (e.g. `bash`, `guile`).

- A list of three string entries and a boolean entry:
the first string must contain the command to start the REPL;
the second and third must contain strings to prepend and append to code sent to the REPL,
respectively.
This is sometimes necessary to enable sending several lines of code to the REPL at once.
The fourth element of the list must be either 0 or 1,
and it controls whether an additional `<cr>` should be appended to the code chunks that are followed by a blank line.
(This can be useful to avoid the need to press `<cr>` manually in the terminal window.
In `ipython`, for example, two `<cr>` are required to run an indented block.)

The current default is the following:
```vim
let s:default_repls = {
            \ "python": ["ipython", "\<c-u>\<esc>[200~", "\<esc>[201~"], 1]
            \ "scheme": "guile",
            \ "sh": "bash"
            \ }
```

## Mappings

The functions are exposed via `<Plug>` mappings.
If `g:ripple_enable_mappings` is set to `1`,
then additional mappings to keys are defined as follows:

| `<Plug>` Mapping                | Default key mapping | Description                |
| -----------------------------   | ------------------- | -----------                |
| `<Plug>(ripple_open_repl)`      | `y<cr>` (`nmap`)    | Open REPL                  |
| `<Plug>(ripple_send_motion)`    | `yr` (`nmap`)       | Send motion to REPL        |
| `<Plug>(ripple_send_previous)`  | `yp` (`nmap`)       | Resend previous code block |
| `<Plug>(ripple_send_selection)` | `R` (`xmap`)        | Send selection to REPL     |
| `<Plug>(ripple_send_line)`      | `yrr` (`nmap`)      | Send line to REPL          |

If `<Plug>(ripple_send_motion)` is issued but no REPL is open,
a REPL will open automatically.
A mnemonic for `yr` is *you run*.

## Additional customization

| Config                               | Default             | Description                           |
| ------                               | -------             | -----------                           |
| `g:ripple_window` (`nvim` only)      | `vnew`              | The command to open the REPL window   |
| `g:ripple_term_command` (`vim` only) | `vertical terminal` | The command to open the REPL terminal |
| `g:ripple_enable_mappings`           | `1`                 | Whether to enable default mappings    |
| `g:ripple_highlight`                 | `DiffAdd`           | Highlight group                       |

To disable th highlighting of code chunks sent to the REPL, simply `let g:ripple_highlight = ""`.
Highlighting works only when the plugin [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed.

## License

MIT
