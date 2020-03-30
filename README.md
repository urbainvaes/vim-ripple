# Ripple

This thin `nvim` plugin makes it easy to interact with a REPL (read-evaluate-print loop).
Some of the advantages of this plugin over some the alternative software are the following:

- This plugin is written in `viml`, so it does not require to `updateRemotePlugins`.

- The cursor position does not change when a code chunk is sent to the REPL.

- If [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed, 
motions sent to the REPL are highlighted.

- If not explicitly opened by `<Plug>(ripple_open_repl)`, 
the REPL opens automatically once a code chunk is sent.

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

- A string containing the command to start the REPL (e.g. `ipython`, `guile`).

- A list with three string entries:
the first must cointain the command to start the REPL;
the second and third must contain strings to prepend and append to code sent to the REPL,
respectively.
This is sometimes necessary to enable bracketed paste,
i.e. to enable sending several lines of code to the REPL at once.

The current default is the following:
```vim
let s:default_repls = {
            \ "python": ["ipython", "\<esc>[200~", "\<esc>[201~"],
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

| Config                     | Default   | Description                         |
| ------                     | -------   | -----------                         |
| `g:ripple_window`          | `vnew`    | The command to open the REPL window |
| `g:ripple_enable_mappings` | `1`       | Whether to enable default mappings  |
| `g:ripple_highlight`       | `DiffAdd` | Highlight group                     |

To disable highlighting of code chunks sent to the REPL, simply `let g:ripple_highlight = ""`.
Highlighting works only when the plugin [vim-highlightedyank](https://github.com/machakann/vim-highlightedyank) is installed.

## License

MIT
