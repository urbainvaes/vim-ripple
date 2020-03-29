# Ripple

This thin `nvim` plugin makes it easy to interact with a REPL (read-evaluate-print loop).

# Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'urbainvaes/vim-ripple'
```

# Configuration of the REPLs

New REPLs can defined in a dictionary.
These definition take precedence over the default REPLs defined in the plugin.
In the dictionary, the keys are the `filetype`s,
and the values are either of the following:

- A string containing the command to start the REPL (e.g. `ipython`, `guile`).

- A list with three string entries:
the first must cointain the command to start the REPL (e.g. `ipython`, `guile`);
the second and third must contain strings to prepend and append to code sent to the terminal,
respectively. This is sometimes necessary to enable bracketed paste.

The current default is the following:
```vim
let s:default_repls = {
            \ "python": ["ipython", "\<esc>[200~", "\<esc>[201~"],
            \ "scheme": "guile",
            \ "sh": "bash"
            \ }
```

# Additional customization

| Config            | Default | Description |
| ------            | ------- | ----------- |
| `g:ripple_window` | `vnew`  | The command to open the REPL window |

# License

MIT
