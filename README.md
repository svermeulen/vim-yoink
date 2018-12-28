
<img align="right" width="182" height="355" src="https://i.imgur.com/o5nyLHm.png">

# Yoink.vim

This is just another killring style vim plugin similar to [nvim-miniyank](https://github.com/bfredl/nvim-miniyank), [YankRing.vim](https://github.com/vim-scripts/YankRing.vim), [vim-yankstack](https://github.com/maxbrunsfeld/vim-yankstack) or the yank features in [vim-easyclip](https://github.com/svermeulen/vim-easyclip).

Note: Requires either Neovim or Vim 8+, and also vim-repeat to be installed alongside it

Also Note:  This plugin requires [this PR](https://github.com/tpope/vim-repeat/pull/66) to vim-repeat to be merged to work properly

## Example Config

Note that there are no default mappings.  Yoink will automatically record all yanks into a history by observing the `TextYankPost` autocommand added in Neovim and Vim 8+.  But you will need to define some mappings to navigate this history.  For example:

```viml
nmap [y <plug>(YoinkRotateBack)
nmap ]y <plug>(YoinkRotateForward)

nmap <c-n> <plug>(YoinkPostPasteSwapBack)
nmap <c-p> <plug>(YoinkPostPasteSwapForward)

nmap p <plug>(YoinkPaste_p)
nmap P <plug>(YoinkPaste_P)

xmap p <plug>(YoinkPasteVisualMode)
xmap P <plug>(YoinkPasteVisualMode)
```

With these mappings, immediately after performing a paste, you can cycle through the history by hitting `<c-n>` and `<c-p>`.  Note that this will only affect the current paste and the history order will be unchanged.  However - if you do want to permanently cycle through the history, you can do this using the `[y` and `]y` keys.

We also need to override the `p` and `P` keys to notify Yoink that a paste has occurred, so that swapping via the `<c-n>` and `<c-p>` keys can be enabled.

You can also view the current history by executing the command `:Yanks`.  And you can clear the history by executing `:ClearYanks`

## Settings

You can optionally override the default behaviour with the following settings:

`g:yoinkMaxItems` - History size. Default: `20`
`g:yoinkIncludeDeleteOperations` - When true, delete operations such as `x` or `d` or `s` will also be added to the yank history.  Default: `0`
`g:yoinkSyncSystemClipboardOnFocus` - When false, the System Clipboard feature described below will be disabled

## System Clipboard

Another feature worth mentioning is that if you have `&clipboard` set to either `unnamed` or `unnamedplus` then Yoink will automatically record yanks that have occurred outside of vim.  It does this by observing the `FocusGained` autocommand and then checking if the system clipboard was changed and if so adding it to the history.

