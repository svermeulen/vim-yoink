
if exists('g:yoinkInitialized')
    finish
endif
let g:yoinkInitialized = 1

if !has("nvim")
    try
        augroup _YoinkCompatibleCheck
            au!
            autocmd TextYankPost * let g:yoinkInitialized = 1
        augroup END
    catch
        echoerr "Yoink requires neovim or a version of Vim that supports the TextYankPost autocommand (Vim 8+)"
        finish
    endtry

    augroup _YoinkCompatibleCheck
        au!
    augroup END
endif

augroup _Yoink
    au!
    autocmd TextYankPost * call yoink#onYank(copy(v:event))
    autocmd VimEnter * call yoink#onVimEnter()
augroup END

" <c-u> because count is handled internally to each of these
nnoremap <silent> <plug>(YoinkRotateForward) :<c-u>call yoink#rotateThenPrint(-1)<cr>
nnoremap <silent> <plug>(YoinkRotateBack) :<c-u>call yoink#rotateThenPrint(1)<cr>

nnoremap <silent> <plug>(YoinkPostPasteSwapForward) :<c-u>call yoink#postPasteSwap(-1)<cr>
nnoremap <silent> <plug>(YoinkPostPasteSwapBack) :<c-u>call yoink#postPasteSwap(1)<cr>

" We use opfunc here to make it work correctly with repeat `.` operation
nnoremap <silent> <plug>(YoinkPaste_p) :<c-u>call yoink#setupPaste('p', v:register, v:count)<cr>:set opfunc=yoink#paste<cr>g@l
nnoremap <silent> <plug>(YoinkPaste_P) :<c-u>call yoink#setupPaste('P', v:register, v:count)<cr>:set opfunc=yoink#paste<cr>g@l

nnoremap <silent> <plug>(YoinkPostPasteToggleFormat) :<c-u>call yoink#postPasteToggleFormat()<cr>

nnoremap <silent> <expr> <plug>(YoinkYankPreserveCursorPosition) yoink#startYankPreserveCursorPosition()
xnoremap <silent> <expr> <plug>(YoinkYankPreserveCursorPosition) yoink#startYankPreserveCursorPosition()

command! -nargs=0 Yanks call yoink#showYanks()
command! -nargs=0 ClearYanks call yoink#clearYanks()

