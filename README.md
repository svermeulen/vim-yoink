
<img align="right" width="182" height="355" src="https://i.imgur.com/o5nyLHm.png">

# Yoink.vim

This is just another killring style vim plugin similar to [nvim-miniyank](https://github.com/bfredl/nvim-miniyank), [YankRing.vim](https://github.com/vim-scripts/YankRing.vim), [vim-yankstack](https://github.com/maxbrunsfeld/vim-yankstack) or the yank features in [vim-easyclip](https://github.com/svermeulen/vim-easyclip).

## Example Config

Note that there are no default mappings.  Yoink will automatically record all yanks into a history by observing the TextYankPost autocommand added in Neovim and Vim 8+.  But you will need to define some mappings to navigate this history.  For example:

```viml
nnoremap [y <plug>(YoinkRotateBack)
nnoremap ]y <plug>(YoinkRotateForward)

nnoremap <c-n> <plug>(YoinkPostPasteSwapBack)
nnoremap <c-p> <plug>(YoinkPostPasteSwapForward)
```

With these mappings, immediately after performing a paste, you can cycle through the history by hitting `<c-n>` and `<c-p>`.  Note that this will not affect the history after the swap completes.  If you want to permanently cycle through the history, you can do this using the `[y` and `]y` keys.

You can also view the current history by executing the command `:Yanks`.  And you can clear the history by executing `:ClearYanks`

## System Clipboard

Another feature worth mentioning is that if you have `clipboard` set to either `unnamed` or `unnamedplus` then Yoink will automatically record yanks that have occurred outside of vim.  It does this by observing the FocusGained autocommand and then checking if the system clipboard was changed and if so then it adds it to the history.

