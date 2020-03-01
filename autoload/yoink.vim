
scriptencoding utf-8

let g:yoinkMaxItems = get(g:, 'yoinkMaxItems', 10)
let g:yoinkShowYanksWidth = get(g:, 'yoinkShowYanksWidth', 80)
let g:yoinkIncludeDeleteOperations = get(g:, 'yoinkIncludeDeleteOperations', 0)
let g:yoinkAutoFormatPaste = get(g:, 'yoinkAutoFormatPaste', 0)
let g:yoinkMoveCursorToEndOfPaste = get(g:, 'yoinkMoveCursorToEndOfPaste', 0)
let g:yoinkSyncNumberedRegisters = get(g:, 'yoinkSyncNumberedRegisters', 0)
let g:yoinkSwapClampAtEnds = get(g:, 'yoinkSwapClampAtEnds', 1)
let g:yoinkIncludeNamedRegisters = get(g:, 'yoinkIncludeNamedRegisters', 1)
let g:yoinkChangeTickThreshold = get(g:, 'yoinkChangeTickThreshold', 0)

let s:saveHistoryToShada = get(g:, 'yoinkSavePersistently', 0)
let s:autoFormat = get(g:, 'yoinkAutoFormatPaste', 0)
let s:lastPasteChangedtick = -1
let s:isSwapping = 0
let s:hasMovedFromPaste = 0
let s:offsetSum = 0
let s:focusLostInfo = {}

let s:historyChangedCallbacks = []
let s:yankStartCursorPos = []
let s:yankStartWinView = {}

let s:cnt = 1
let s:currentPasteType = ''
let s:currentPasteRegister = ''

let s:isCutlassInstalled = 0
try
    call cutlass#getVersion()
    let s:isCutlassInstalled = 1
catch /\Vcutlass#getVersion/
endtry

if s:isCutlassInstalled && !g:yoinkIncludeDeleteOperations
    echoerr "Detected both cutlass and yoink installed - however g:yoinkIncludeDeleteOperations is set to 0.  You probably want to set it to 1 instead so that your binding for cut will be added to the yank history"
endif

if s:saveHistoryToShada
    if !exists("g:YOINK_HISTORY")
        let g:YOINK_HISTORY = []
    endif

    if !has("nvim")
        echoerr "Neovim is required when setting g:yoinkSavePersistently to 1"
    elseif &shada !~ '\V!'
        echoerr "Must enable global variable support by including ! in the shada property when setting g:yoinkSavePersistently to 1.  See yoink documentation for details or run :help 'shada'."
    endif
else
    let s:history = []
    " If the setting is off then clear it to not keep taking up space
    let g:YOINK_HISTORY = []
endif

function! s:clearYankStartData()
    let s:yankStartCursorPos = []
    let s:yankStartWinView = {}

    augroup YoinkYankStartClear
        autocmd!
    augroup END
endfunction

function! yoink#startYankPreserveCursorPosition()
    let s:yankStartCursorPos = getpos('.')
    let s:yankStartWinView = winsaveview()

    augroup YoinkYankStartClear
        autocmd!
        autocmd CursorMoved <buffer> call <sid>clearYankStartData()
    augroup END

    return "y"
endfunction

function! yoink#getYankHistory()
    if s:saveHistoryToShada
        return g:YOINK_HISTORY
    endif

    return s:history
endfunction

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

function! yoink#setupPaste(pasteType, reg, cnt)
    let s:currentPasteType = a:pasteType
    let s:currentPasteRegister = a:reg
    let s:cnt = a:cnt > 0 ? a:cnt : 1

    if a:reg == "_"
        let s:currentPasteRegister = yoink#getDefaultReg()
    endif
endfunction

function! yoink#adjustLastChangeIfNecessary()
    if s:autoFormat
        " For some reason, the format operation does not update the ] mark properly so we
        " have to do this manually
        let endPos = getpos("']")
        let oldIndentAmount = indent(endPos[1])
        silent exec "keepjumps normal! `[=`]"
        let newIndentAmount = indent(endPos[1])
        let endPos[2] += newIndentAmount - oldIndentAmount
        call setpos("']", endPos)
    endif

    if g:yoinkMoveCursorToEndOfPaste
        call setpos(".", getpos("']"))
    else
        if s:autoFormat
            " Default vim behaviour is to place cursor at the beginning of the new text
            " Auto format can change this sometimes so ensure this is fixed
            call setpos(".", getpos("'["))
        else
            " Do nothing
            " Make sure paste with yoinkAutoFormatPaste and yoinkMoveCursorToEndOfPaste off is
            " always identical to normal vim
        endif
    endif
endfunction

function! yoink#paste(...)
    let previousPosition = getpos('.')
    exec "normal! \"" . s:currentPasteRegister . s:cnt . s:currentPasteType

    call yoink#adjustLastChangeIfNecessary()

    if g:yoinkMoveCursorToEndOfPaste
        let newPosition = getpos('.')
        if abs(newPosition[1] - previousPosition[1]) > 1
            " Only add to the jump list if the paste moved the cursor more than 1 line
            call setpos('.', previousPosition)
            normal! m`
            call setpos('.', newPosition)
        endif
    endif

    call yoink#startUndoRepeatSwap()
endfunction

function! yoink#postPasteToggleFormat()
    if s:tryStartSwap()
        let s:autoFormat = !s:autoFormat
        echo "Turned " . (s:autoFormat ? "on" : "off") . " formatting"
        call s:performSwap()
    endif
endfunction

function s:isCloseEnoughChangeTick(tick)
    return abs(b:changedtick - a:tick) <= g:yoinkChangeTickThreshold 
endfunction

function! s:tryStartSwap()
    " If a change occurred that was not a paste or a swap, we do not want to do the undo-redo
    " Also, if the swap has ended by executing a cursor move, then we don't want to
    " restart the swap again from the beginning because they would expect to still be at the
    " previous offset
    if !yoink#canSwap()
        echo 'Last action was not paste - swap ignored'
        return 0
    endif

    if !s:isSwapping
        " This is necessary in the case where the default register is different from the first
        " element in the history, which can happen a lot with deletes
        " In this case add it to the history even though they might have yoinkIncludeDeleteOperations
        " set to false
        " Otherwise they will lose it completely since we clobber the default register to make
        " swapping work
        " So probably better to preserve it even though adding it to history violates yoinkIncludeDeleteOperations
        call yoink#addCurrentDefaultRegToHistory()

        let s:isSwapping = 1
        let s:offsetSum = 0
    endif

    return 1
endfunction

function! s:performSwap()
    normal! u.
endfunction

function! yoink#postPasteSwap(offset)

    if !s:tryStartSwap()
        return
    endif

    let cnt = v:count > 0 ? v:count : 1
    let offset = a:offset * cnt

    let history = yoink#getYankHistory()

    if g:yoinkSwapClampAtEnds
        if s:offsetSum + offset < 0
            echo 'Reached most recent item'
            return
        endif

        if s:offsetSum + offset >= len(history)
            echo 'Reached oldest item'
            return
        endif
    endif

    let s:offsetSum += yoink#rotate(offset)

    call s:performSwap()
endfunction

function! s:postPasteMove2()
    augroup YoinkYankPostPasteMove
        autocmd!
    augroup END

    let s:hasMovedFromPaste = 1

    if s:isSwapping
        let s:isSwapping = 0
        let s:autoFormat = g:yoinkAutoFormatPaste

        " Return yank positions to their original state before we started swapping
        call yoink#rotate(-s:offsetSum)
    endif
endfunction

function! s:postPasteMove1()
    augroup YoinkYankPostPasteMove
        autocmd!
        autocmd CursorMoved <buffer> call <sid>postPasteMove2()
    augroup END
endfunction

" Note that this gets executed for every swap in addition to the initial paste
function! yoink#startUndoRepeatSwap()
    let s:lastPasteChangedtick = b:changedtick

    let s:hasMovedFromPaste = 0
    " We want to disable the ability to swap if the cursor moves after this point
    augroup YoinkYankPostPasteMove
        autocmd!
        autocmd CursorMoved <buffer> call <sid>postPasteMove1()
    augroup END
endfunction

function! yoink#observeHistoryChangeEvent(callback)
    call add(s:historyChangedCallbacks, a:callback)
endfunction

function! s:onHistoryChanged()
    if g:yoinkSyncNumberedRegisters
        let history = yoink#getYankHistory()

        " We skip the first one because it's assumed that's set to the default register
        " already (or failing that, the '0' register)
        for i in range(1, min([len(history) - 1, 9]))
            let entry = history[i]
            call setreg(i, entry.text, entry.type)
        endfor
    endif

    for Callback in s:historyChangedCallbacks
        call Callback()
    endfor
endfunction

function! yoink#addTextToHistory(text, ...)
    let regType = a:0 ? a:1 : 'v'
    let entry = { 'text': a:text, 'type': regType }
    " Add as second element to keep the default register at the beginning
    call s:addToHistory(entry, 1)
endfunction

function! s:addToHistory(entry, ...)
    let offset = a:0 ? a:1 : 0
    let history = yoink#getYankHistory()

    if !empty(a:entry.text) && (empty(history) || (a:entry != history[0]))
        " Remove it if it is already added somewhere in the history
        for i in range(len(history))
            if history[i] ==# a:entry
                if i <= offset
                    return
                endif
                call remove(history, i)
                break
            endif
        endfor

        call insert(history, a:entry, min([offset, len(history)]))
        if len(history) > g:yoinkMaxItems
            call remove(history, g:yoinkMaxItems, -1)
        endif
        call s:onHistoryChanged()
        return 1
    endif

    return 0
endfunction

" Returns the amount rotated
function! yoink#rotate(offset)
    let history = yoink#getYankHistory()

    if empty(history) || a:offset == 0
        return 0
    endif

    " If the default register has contents different than the first entry in our history,
    " then it must have changed through a delete operation or directly via setreg etc.
    " In this case, don't rotate and instead just update the default register
    if history[0] != yoink#getDefaultYankInfo()
        call yoink#setDefaultYankInfo(history[0])
        call s:onHistoryChanged()
        return 0
    endif

    let actualOffset = float2nr(fmod(a:offset, len(history)))
    " Mod to save ourselves some work
    let offsetLeft = actualOffset

    while offsetLeft != 0
        if offsetLeft > 0
            let l:entry = remove(history, 0)
            call add(history, l:entry)
            let offsetLeft -= 1
        elseif offsetLeft < 0
            let l:entry = remove(history, -1)
            call insert(history, l:entry)
            let offsetLeft += 1
        endif
    endwhile

    call yoink#setDefaultYankInfo(history[0])
    call s:onHistoryChanged()
    return actualOffset
endfunction

function! yoink#addCurrentDefaultRegToHistory()
    let history = yoink#getYankHistory()
    let entry = yoink#getDefaultYankInfo()

    if len(history) == 0 || history[0] != entry
        call s:addToHistory(entry)
    endif
endfunction

function! yoink#clearYanks()
    let history = yoink#getYankHistory()
    let previousSize = len(history)
    call remove(history, 0, -1)
    call yoink#addCurrentDefaultRegToHistory()
    echo "Cleared yank history of " . previousSize . " entries"
endfunction

function! yoink#getDefaultYankText()
    return yoink#getDefaultYankInfo().text
endfunction

function! yoink#getDefaultYankInfo()
    return yoink#getYankInfoForReg(yoink#getDefaultReg())
endfunction

function! yoink#setDefaultYankText(text)
    call setreg(yoink#getDefaultReg(), a:text, 'v')
endfunction

function! yoink#setDefaultYankInfo(entry)
    call setreg(yoink#getDefaultReg(), a:entry.text, a:entry.type)
endfunction

function! yoink#getYankInfoForReg(reg)
    return { 'text': getreg(a:reg), 'type': getregtype(a:reg) }
endfunction

function! yoink#canSwap()
    return s:isCloseEnoughChangeTick(s:lastPasteChangedtick) && !s:hasMovedFromPaste
endfunction

function! yoink#isSwapping()
    return s:isSwapping
endfunction

function! yoink#showYanks()
    echohl WarningMsg | echo "--- Yanks ---" | echohl None
    let i = 0
    for yank in yoink#getYankHistory()
        call s:showYank(yank, i)
        let i += 1
    endfor
endfunction

function! s:showYank(yank, index)
    let index = printf("%-4d", a:index)

    let line = a:yank.text

    if len(line) > g:yoinkShowYanksWidth
        let line = line[: g:yoinkShowYanksWidth] . '…'
    endif

    let line = substitute(line, '\V\n', '^M', 'g')

    echohl Directory | echo  index
    echohl None      | echon line
    echohl None
endfunction

function! yoink#rotateThenPrint(offset)
    let cnt = v:count > 0 ? v:count : 1
    let offset = a:offset * cnt
    call yoink#rotate(offset)

    let lines = split(yoink#getDefaultYankText(), '\n')

    if empty(lines)
        " This happens when it only contains newlines
        echo "Current Yank: "
    else
        echo "Current Yank: " . lines[0]
    endif
endfunction

function! yoink#onVimEnter()
    call yoink#addCurrentDefaultRegToHistory()

    if get(g:, 'yoinkSyncSystemClipboardOnFocus', 1)
        augroup _YoinkSystemSync
            au!
            autocmd FocusGained * call yoink#onFocusGained()
            autocmd FocusLost * call yoink#onFocusLost()
        augroup END
    endif
endfunction

function! yoink#onFocusLost()
    let s:focusLostInfo = yoink#getDefaultYankInfo()
endfunction

function! yoink#onFocusGained()
    if len(s:focusLostInfo) == 0
        return
    endif

    let defaultReg = yoink#getDefaultReg()

    if defaultReg ==# '*' || defaultReg == '+'
        let entry = yoink#getDefaultYankInfo()

        if s:focusLostInfo != entry
            " User copied something outside of vim
            call yoink#addCurrentDefaultRegToHistory()
        endif
    endif
endfunction

" Call this to simulate a yank from the user
function! yoink#manualYank(text, ...) abort
    let regType = a:0 ? a:1 : 'v'
    let entry = { 'text': a:text, 'type': regType }
    call s:addToHistory(entry)
    call yoink#setDefaultYankInfo(entry)
endfunction

function! yoink#onYank(ev) abort
    if (a:ev.operator == 'y' || g:yoinkIncludeDeleteOperations)

        let isDefaultRegister = a:ev.regname == '' || a:ev.regname == yoink#getDefaultReg()

        if isDefaultRegister || g:yoinkIncludeNamedRegisters

            " We don't use a:ev.regcontents because it's a list of lines and not the raw text
            " The raw text is needed when comparing getDefaultYankInfo in a few places
            " above
            let entry = { 'text': getreg(a:ev.regname), 'type': a:ev.regtype }

            " We add an offset for named registers so that the default register is always at 
            " index 0 in the yank history
            call s:addToHistory(entry, isDefaultRegister ? 0 : 1)
        endif
    end

    if (a:ev.operator == 'y' && len(s:yankStartCursorPos) > 0)
        call setpos('.', s:yankStartCursorPos)
        call winrestview(s:yankStartWinView)
        call s:clearYankStartData()
    endif
endfunction

" For when re-sourcing this file after a paste
augroup YoinkYankPostPasteMove
    autocmd!
augroup END

