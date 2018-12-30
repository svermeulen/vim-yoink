
<img align="right" width="182" height="355" src="https://i.imgur.com/o5nyLHm.png">

# Yoink.vim

This is just another killring style vim plugin similar to [nvim-miniyank](https://github.com/bfredl/nvim-miniyank), [YankRing.vim](https://github.com/vim-scripts/YankRing.vim), [vim-yankstack](https://github.com/maxbrunsfeld/vim-yankstack) or the yank features in [vim-easyclip](https://github.com/svermeulen/vim-easyclip).

Note: Requires either Neovim or Vim 8+, and also vim-repeat to be installed alongside it

Also Note:  This plugin requires [this PR](https://github.com/tpope/vim-repeat/pull/66) to vim-repeat to be merged to work properly (or you can directly use [svermeulen/vim-repeat](https://github.com/svermeulen/vim-repeat))

## Mappings

Note that there are no default mappings.  Yoink will automatically record all yanks into a history by observing the `TextYankPost` autocommand added in Neovim and Vim 8+.  But you will need to define some mappings to navigate this history.  

You will at least want to define maps for paste and swap paste:

```viml
nmap <c-n> <plug>(YoinkPostPasteSwapBack)
nmap <c-p> <plug>(YoinkPostPasteSwapForward)

nmap p <plug>(YoinkPaste_p)
nmap P <plug>(YoinkPaste_P)
```

With these mappings, immediately after performing a paste, you can cycle through the history by hitting `<c-n>` and `<c-p>`

We also need to override the `p` and `P` keys to notify Yoink that a paste has occurred, so that swapping via the `<c-n>` and `<c-p>` keys can be enabled.

Note that the swap operations above will only affect the current paste and the history order will be unchanged.  However - if you do want to permanently cycle through the history, you can do that too:

```viml
nmap [y <plug>(YoinkRotateBack)
nmap ]y <plug>(YoinkRotateForward)
```

You might also want to add a map for toggling whether the current paste is formatted or not:

```viml
nmap <c-=> <plug>(YoinkPostPasteToggleFormat)
```

Now, hitting `<c-=>` after a paste will toggle between formatted and unformatted (equivalent to using the `=` key).  By default pastes will not be formatted until you toggle it afterwards using `<c-=>` (however you can change this with a setting as described below)

Note that yoink does not support swapping when doing paste in visual mode.  However, if you also install [vim-subversive](https://github.com/svermeulen/vim-subversive), that actually does contain a map you can use for that.

## Commands

`:Yanks` - Display the current yank history

`:ClearYanks` - Delete history

## Settings

You can optionally override the default behaviour with the following settings:

- `g:yoinkMaxItems` - History size. Default: `20`
- `g:yoinkIncludeDeleteOperations` - When set to `1`, delete operations such as `x` or `d` or `s` will also be added to the yank history.  Default: `0`
- `g:yoinkSavePersistently` - When set to `1`, the yank history will be saved persistently across sessions of vim.  Note: Requires Neovim.  See <a href="#shada-support">here</a> for details. Default: `0`
- `g:yoinkSyncSystemClipboardOnFocus` - When set to `0`, the System Clipboard feature described below will be disabled.  Default: `1`
- `g:yoinkAutoFormatPaste` - When set to `1`, after a paste occurs it will automatically be formatted (using `=` key).  Default: `0`.  Note that you can leave this off and just use the toggle key instead for cases where you want to format after the paste.
- `g:yoinkMoveCursorToEndOfPaste` - When set to `1`, the cursor will always be placed at the end of the paste.  Default is to match normal vim behaviour (`0`) which places cursor at the beginning when pasting multiline yanks.  Setting to `1` can be nicer because it makes the post-paste cursor position more consistent between multiline and non-multiline pastes (that is, it is at the end in both cases).  And also causes consecutive multiline pastes to be ordered correctly.

## <a id="shada-support"></a>Persistent/Shared History

When `g:yoinkSavePersistently` is set to 1, the yank history will be saved persistently by taking advantage of Neovim's "ShaDa" feature (Note: therefore this is not possible with Vim).

You can also use this feature to sync the yank history across multiple running instances of vim by updating Neovim's shada file by running `:wshada` in the first instance and then `rshada` in the second instance.

## System Clipboard

Another feature worth mentioning is that if you have `&clipboard` set to either `unnamed` or `unnamedplus` then Yoink will automatically record yanks that have occurred outside of vim.  It does this by observing the `FocusGained` autocommand and then checking if the system clipboard was changed and if so adding it to the history.

## Other Notes

* If you want to add to the yank history from your own vimscript code, you can do this by calling `yoink#manualYank`

