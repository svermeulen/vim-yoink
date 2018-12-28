
scriptencoding utf-8

let s:lastPasteChangedtick = -1
let s:history = []
let s:isSwapping = 0
let s:offsetSum = 0

function! yoink#getDefaultReg()
    let clipboardFlags = split(&clipboard, ',')
    if index(clipboardFlags, 'unnamedplus') >= 0
        return "+"
    elseif index(clipboardFlags, 'unnamed') >= 0
        return "*"
    else
        return "\""
    endif
endfunction

function! yoink#wasLastChangePaste()
    return b:changedtick == s:lastPasteChangedtick
endfunction

function! s:postSwapCursorMove2()
    if !s:isSwapping
        " Should never happen
        throw 'Unknown Error detected during yoink paste'
    endif

    let s:isSwapping = 0

    augroup YoinkSwapPasteMoveDetect
        autocmd!
    augroup END

    " Return yank positions to their original state before we started swapping
    call yoink#rotate(-s:offsetSum)
endfunction

function! s:postSwapCursorMove1()
    " Wait for the next cursor move because this gets called immediately after yoink#postPasteSwap
    augroup YoinkSwapPasteMoveDetect
        autocmd!
        autocmd CursorMoved <buffer> call <sid>postSwapCursorMove2()
    augroup END
endfunction

function! yoink#postPasteSwap(offset)
    if !yoink#wasLastChangePaste()
        echo 'Last action was not paste, swap ignored'
        return
    endif

    if s:isSwapping
        " Stop checking to end the swap session
        augroup YoinkSwapPasteMoveDetect
            autocmd!
        augroup END
    else
        let s:isSwapping = 1
        let s:offsetSum = 0
    endif

    call yoink#rotate(a:offset)
    let s:offsetSum += a:offset
    exec 'normal! u.'

    " When we undo-redo you might expect the changed tick to be unchanged but this is not
    " the case for some reason, so we have to update it
    let s:lastPasteChangedtick = b:changedtick

    augroup YoinkSwapPasteMoveDetect
        autocmd!
        autocmd CursorMoved <buffer> call <sid>postSwapCursorMove1()
    augroup END
endfunction

function! yoink#onPostPaste()
    let s:lastPasteChangedtick = b:changedtick
endfunction

function! yoink#setDefaultReg(entry)
    call setreg(yoink#getDefaultReg(), a:entry.text, a:entry.type)
endfunction

function! yoink#onHistoryChanged()
    " sync numbered registers
    for i in range(1, min([len(s:history), 9]))
        let entry = s:history[i-1]
        call setreg(i, entry.text, entry.type)
    endfor
endfunction

function! yoink#tryAddToHistory(entry)
    if !empty(a:entry.text) && (empty(s:history) || (a:entry != s:history[0]))
        " If it's already in history then just move it to the front to avoid duplicates
        for i in range(len(s:history))
            if s:history[i] ==# a:entry
                call remove(s:history, i)
                break
            endif
        endfor

        call insert(s:history, a:entry)
        if len(s:history) > g:yoinkMaxItems
            call remove(s:history, g:yoinkMaxItems, -1)
        endif
        call yoink#onHistoryChanged()
    endif
endfunction

function! yoink#rotate(offset)
    if empty(s:history) || a:offset == 0
        return
    endif

    let offsetLeft = a:offset

    while offsetLeft != 0
        if offsetLeft > 0
            let l:entry = remove(s:history, 0)
            call add(s:history, l:entry)
            let offsetLeft -= 1
        elseif offsetLeft < 0
            let l:entry = remove(s:history, -1)
            call insert(s:history, l:entry)
            let offsetLeft += 1
        endif
    endwhile

    call yoink#setDefaultReg(s:history[0])
    call yoink#onHistoryChanged()
endfunction

function! yoink#addCurrentToHistory()
    call yoink#tryAddToHistory(yoink#getCurrentYankInfo())
endfunction

function! yoink#clearYanks()
    let l:size = len(s:history)
    let s:history = []
    call yoink#addCurrentToHistory()
    echo "Cleared yank history of " . l:size . " entries"
endfunction

function! yoink#getCurrentYankInfo()
    return yoink#getYankInfoForReg(yoink#getDefaultReg())
endfunction

function! yoink#getYankInfoForReg(reg)
    return { 'text': getreg(a:reg), 'type': getregtype(a:reg) }
endfunction

function! yoink#getYankHistory()
    return s:history
endfunction

function! yoink#showYanks()
    echohl WarningMsg | echo "--- Yanks ---" | echohl None
    let i = 0
    for yank in s:history
        call yoink#showYank(yank, i)
        let i += 1
    endfor
endfunction

function! yoink#showYank(yank, index)
    let index = printf("%-4d", a:index)
    let line = substitute(a:yank.text, '\V\n', '^M', 'g')

    if len(line) > g:yoinkShowYanksWidth
        let line = line[: g:yoinkShowYanksWidth] . '…'
    endif

    echohl Directory | echo  index
    echohl None      | echon line
    echohl None
endfunction

function! yoink#rotateThenPrint(offset)
    call yoink#rotate(a:offset)

    let lines = split(yoink#getCurrentYankInfo().text, '\n')

    if empty(lines)
        " This happens when it only contains newlines
        echo "Current Yank: "
    else
        echo "Current Yank: " . lines[0]
    endif
endfunction

function! yoink#onFocusGained()
    " If we are using the system register as the default register
    " and the user leaves vim, copies something, then returns,
    " we want to add this data to the yank history
    let defaultReg = yoink#getDefaultReg()
    if defaultReg ==# '*' || defaultReg == '+'
        let currentInfo = yoink#getCurrentYankInfo()

        if len(s:history) == 0 || s:history[0] != currentInfo
            " User copied something externally
            call yoink#tryAddToHistory(currentInfo)
        endif
    endif
endfunction

function! yoink#onYank(ev) abort
    if len(a:ev.regcontents) == 1 && len(a:ev.regcontents[0]) <= 1
        return
    end

    if a:ev.operator == 'y' && (a:ev.regname == '' || a:ev.regname == yoink#getDefaultReg())
        call yoink#tryAddToHistory({ 'text': join(a:ev.regcontents, '\n'), 'type': a:ev.regtype })
    end
endfunction

