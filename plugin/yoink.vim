
if exists('g:yoinkInitialized')
    finish
endif
let g:yoinkInitialized = 1

if !has("nvim")
   echoerr "yoink requires neovim"
   finish
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

if !has_key(g:, "yoinkMaxItems")
    let g:yoinkMaxItems = 20
endif

if !has_key(g:, "yoinkShowYanksWidth")
    let g:yoinkShowYanksWidth = 80
endif

if !has_key(g:, "yoinkIncludeDeleteOperations")
    let g:yoinkIncludeDeleteOperations = 0
endif

if !has_key(g:, "yoinkSyncSystemClipboardOnFocus")
    let g:yoinkSyncSystemClipboardOnFocus = 1
endif

augroup _Yoink
    au!
    autocmd TextYankPost * call yoink#onYank(copy(v:event))
    autocmd VimEnter * call yoink#addCurrentToHistory()
    autocmd FocusGained * call yoink#onFocusGained()
augroup END

nnoremap <silent> <plug>(YoinkRotateForward) :call yoink#rotateThenPrint(-1)<cr>
nnoremap <silent> <plug>(YoinkRotateBack) :call yoink#rotateThenPrint(1)<cr>

nnoremap <silent> <plug>(YoinkPostPasteSwapForward) :call yoink#postPasteSwap(-1)<cr>
nnoremap <silent> <plug>(YoinkPostPasteSwapBack) :call yoink#postPasteSwap(1)<cr>

nnoremap <silent> <plug>(YoinkPaste_p) p:call yoink#startPasteSwap()<cr>:silent! call repeat#set("\<plug>(YoinkPaste_p)")<cr>
nnoremap <silent> <plug>(YoinkPaste_P) P:call yoink#startPasteSwap()<cr>:silent! call repeat#set("\<plug>(YoinkPaste_P)")<cr>

xnoremap <silent> <plug>(YoinkPasteVisualMode) :call yoink#visualModePaste()<cr>

command! -nargs=0 Yanks call yoink#showYanks()
command! -nargs=0 ClearYanks call yoink#clearYanks()

