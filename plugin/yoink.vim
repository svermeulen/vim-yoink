
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

try
    call repeat#invalidate()
catch /\VUnknown function/
    echoerr 'Could not find vim-repeat installed.  yoink.vim requires vim-repeat to function properly.  Please install vim-repeat and restart Vim'
    finish
catch
    " Sometimes error occurs due to clearing augroup that doesn't exist
    " So just ignore this case
    " Be nice if there was a less hacky way to do this but I can't think of one
    " Checking runtimepath for vim-repeat doesn't work since not everyone uses it that way
    " and some plugin managers actually merge everything together
endtry

augroup _Yoink
    au!
    autocmd TextYankPost * call yoink#onYank(copy(v:event))
    autocmd VimEnter * call yoink#addCurrentToHistory()
    autocmd FocusGained * call yoink#onFocusGained()
augroup END

" <c-u> because count is handled internally to each of these
nnoremap <silent> <plug>(YoinkRotateForward) :<c-u>call yoink#rotateThenPrint(-1)<cr>
nnoremap <silent> <plug>(YoinkRotateBack) :<c-u>call yoink#rotateThenPrint(1)<cr>

nnoremap <silent> <plug>(YoinkPostPasteSwapForward) :<c-u>call yoink#postPasteSwap(-1)<cr>
nnoremap <silent> <plug>(YoinkPostPasteSwapBack) :<c-u>call yoink#postPasteSwap(1)<cr>

nnoremap <silent> <plug>(YoinkPaste_p) :<c-u>call yoink#paste('p', v:register)<cr>
nnoremap <silent> <plug>(YoinkPaste_P) :<c-u>call yoink#paste('P', v:register)<cr>

nnoremap <silent> <plug>(YoinkPostPasteToggleFormat) :<c-u>call yoink#postPasteToggleFormat()<cr>

nnoremap <silent> <expr> <plug>(YoinkYankPreserveCursorPosition) yoink#startYankPreserveCursorPosition()
xnoremap <silent> <expr> <plug>(YoinkYankPreserveCursorPosition) yoink#startYankPreserveCursorPosition()

command! -nargs=0 Yanks call yoink#showYanks()
command! -nargs=0 ClearYanks call yoink#clearYanks()

