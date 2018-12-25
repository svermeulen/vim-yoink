
if exists('g:YoinkInitialized')
    finish
endif

let g:YoinkInitialized = 1

augroup _Yoink
    au! TextYankPost * call yankbuffer#onYank(copy(v:event))
augroup END

