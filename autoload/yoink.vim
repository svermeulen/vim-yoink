
scriptencoding utf-8

let s:lastPasteChangedtick = -1
let s:lastSwapChangedtick = -1
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

function! yoink#paste(pasteType)
    let count = v:count > 0 ? v:count : 1
    exec "normal! " . count . a:pasteType
    call yoink#startPasteSwap()
    silent! call repeat#set("\<plug>(YoinkPaste_" . a:pasteType . ")", count)
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
    " If a change occurred that was not a paste or a swap, we do not want to do the undo-redo
    " Also, if the swap has ended by executing a cursor move, then we don't want to
    " restart the swap again from the beginning because they would expect to still be at the
    " previous offset
    if b:changedtick != s:lastPasteChangedtick || (!s:isSwapping && b:changedtick == s:lastSwapChangedtick)
        echo 'Last action was not paste - swap ignored'
        return
    endif

    if !s:isSwapping
        let s:isSwapping = 1
        let s:offsetSum = 0
    endif

    let count = v:count > 0 ? v:count : 1
    let offset = a:offset * count

    if s:offsetSum + offset < 0
        echo 'Reached most recent item'
        return
    endif

    if s:offsetSum + offset >= len(s:history)
        echo 'Reached oldest item'
        return
    endif

    " Stop checking to end the swap session
    augroup YoinkSwapPasteMoveDetect
        autocmd!
    augroup END

    call yoink#rotate(offset)
    let s:offsetSum += offset
    exec "normal \<Plug>(RepeatUndo)\<Plug>(RepeatDot)"

    let s:lastSwapChangedtick = b:changedtick

    " Wait until the cursor moves and then end the swap
    " We do this so that if they move somewhere else and then paste they would expect the most
    " recent yank and not the yank at the offset where they finished the previous swap
    augroup YoinkSwapPasteMoveDetect
        autocmd!
        autocmd CursorMoved <buffer> call <sid>postSwapCursorMove1()
    augroup END
endfunction

function! yoink#visualModePaste()
    let count = v:count > 0 ? v:count : 1
    normal! gv"_d

    " We need to start the paste as a distinct operation here so that undo applies to it only
    call feedkeys(count . "\<plug>(YoinkPaste_P)", 'tm')
endfunction

" Note that this gets executed for every swap in addition to the initial paste
function! yoink#startPasteSwap()
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

    " If the default register has contents different than the first entry in our history,
    " then it must have changed through a delete operation or directly via setreg etc.
    " In this case, don't rotate and instead just update the default register
    if s:history[0] != yoink#getCurrentYankInfo()
        call yoink#setDefaultReg(s:history[0])
        call yoink#onHistoryChanged()
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
    let count = v:count > 0 ? v:count : 1
    let offset = a:offset * count
    call yoink#rotate(offset)

    let lines = split(yoink#getCurrentYankInfo().text, '\n')

    if empty(lines)
        " This happens when it only contains newlines
        echo "Current Yank: "
    else
        echo "Current Yank: " . lines[0]
    endif
endfunction

function! yoink#onFocusGained()
    if !g:yoinkSyncSystemClipboardOnFocus
        return
    endif

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
    if a:ev.regname != '' && a:ev.regname == yoink#getDefaultReg()
        return
    endif

    if a:ev.operator == 'y' || g:yoinkIncludeDeleteOperations
        call yoink#tryAddToHistory({ 'text': join(a:ev.regcontents, '\n'), 'type': a:ev.regtype })
    end
endfunction

" For when re-sourcing this file after a paste
augroup YoinkSwapPasteMoveDetect
    autocmd!
augroup END

