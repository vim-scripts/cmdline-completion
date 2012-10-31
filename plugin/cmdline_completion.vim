" File:        cmdline_completion.vim
" Author:      kin9 <ljh575@gmail.com>
" Last Change: Oct 31, 2012
"
" Version:     0.04
"              ----- Add search in loaded buffers support .
"
"              0.03
"              ----- Add support cursor at anywhere of cmdline.
"
"
" Description: This script let you can use CTRL-P/N to complete 
"              word in cmdline mode just like in insert mode.
"
"              You can use other keys instead of <C-P/N> like 
"              this : 
"                  cmap <C-J> <Plug>CmdlineCompletionBackward
"                  cmap <C-K> <Plug>CmdlineCompletionForward
"
" Install:     Drag this file into vim plugin directory.
"           
"

if exists("loaded_cmdline_completion") || &cp || version < 700
    finish
endif

let loaded_cmdline_completion = 1

"-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" map key
"
if !hasmapto('<Plug>CmdlineCompletionBackward','c')
    cmap <unique> <silent> <C-P> <Plug>CmdlineCompletionBackward
endif

if !hasmapto('<Plug>CmdlineCompletionForward','c')
    cmap <unique> <silent> <C-N> <Plug>CmdlineCompletionForward
endif

cnoremap <silent> <Plug>CmdlineCompletionBackward 
            \ <C-\>e<SID>CmdlineCompletion(1)<CR>
cnoremap <silent> <Plug>CmdlineCompletionForward 
            \ <C-\>e<SID>CmdlineCompletion(0)<CR>

"-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" auto completion function ,
" return new cmdline with matched word
function! s:CmdlineCompletion(backword)

    let cmdline = getcmdline()
    let cmdpos = getcmdpos() - 1

    let cmdline_tail = strpart(cmdline, cmdpos) 
    let cmdline = strpart(cmdline,0,cmdpos)

    let index = match(cmdline, '\w\+$')
    let cmd = strpart(cmdline, 0, index)

    " Not a word , skip completion
    if index < 0 
        return cmdline . cmdline_tail
    endif

    " s:vars initial if first time or changed cmdline.
    if !exists("b:cc_newcmdline") || cmdline != b:cc_newcmdline
        let b:cc_word_prefix = strpart(cmdline, index)
        let b:cc_word_list = [b:cc_word_prefix]
        let b:cc_word_index = 0
        let b:cc_newcmdline = "" 
        let b:cc_pos_forward = [0,0]
        let b:cc_pos_backward = [0,0]
        let b:cc_search_status = 0
        let b:cc_search_time = ''
        let b:cc_buffer_index = 1
        let b:cc_buffer_pos = [1,0]
        let b:cc_search_status_current = 1
        if version >= 702
            let b:cc_search_total_time = 0
        endif
    endif

    "
    if a:backword
        let b:cc_word_index -= 1
    else
        let b:cc_word_index += 1
    endif

    " try to search new word if index out of list range 
    if ( b:cc_word_index < 0 || b:cc_word_index >= len(b:cc_word_list))
                \ && b:cc_buffer_index <= bufnr('$')

        let start = reltime()

        while b:cc_buffer_index <= bufnr('$')

            " search current first .
            if b:cc_search_status_current 
                let save_cursor = getpos('.')
                let b:cc_search_status_current = s:SearchCurrent(a:backword)
                call setpos('.', save_cursor)
                if  b:cc_search_status_current
                    break 
                endif

                "
                " search other buffers .
            else 
                if b:cc_buffer_index == bufnr('%')
                    let b:cc_buffer_index += 1 
                    continue 
                endif
                let b:cc_search_status =
                            \ s:SearchBuffer(a:backword,b:cc_buffer_index)
                if b:cc_search_status 
                    break 
                else
                    let b:cc_buffer_index += 1 
                    let b:cc_buffer_pos = [1,0]
                endif
            endif

        endwhile


        let b:cc_search_time = reltimestr(reltime(start))
        if version >= 702
            let b:cc_search_total_time += str2float(b:cc_search_time)
        endif
    endif

    " correct index 
    if b:cc_search_status || b:cc_search_status_current
        if b:cc_word_index < 0 
            let b:cc_word_index = 0 
        endif
    else
        if b:cc_word_index < 0 
            let b:cc_word_index = len(b:cc_word_list) - 1
        elseif b:cc_word_index >= len(b:cc_word_list)
            let b:cc_word_index = 0
        endif
    endif

    " get word from list
    let word = get(b:cc_word_list, b:cc_word_index, b:cc_word_prefix)

    " new cmdline
    let b:cc_newcmdline = cmd . word

    " overcome map silent
    call feedkeys(" \<bs>")

    " set new cmdline cursor postion
    call setcmdpos(len(b:cc_newcmdline)+1)

    return  b:cc_newcmdline . cmdline_tail

endfunction


"-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" search completion matched word, 
" return 0 if match none, else return 1 .
function! s:SearchCurrent(backward)

    let position = a:backward ? b:cc_pos_backward : b:cc_pos_forward

    " set last search position
    call cursor(position)

    " search ...
    let pattern = '\<' . b:cc_word_prefix . '\w\+\>'
    let flag = a:backward ? 'web' : 'we'

    " loop search until match unique or none
    let position = searchpos(pattern, flag)
    while position != [0,0]

        if a:backward
            let b:cc_pos_backward = position
        else
            let b:cc_pos_forward = position
        endif

        if b:cc_pos_forward == [0,0] || b:cc_pos_backward == [0,0]
            " store first match position
            let b:cc_pos_forward = position
            let b:cc_pos_backward = position
        elseif b:cc_pos_forward == b:cc_pos_backward
            " wrapscan around the whole file
            return 0
        endif

        " get matched word under cursor
        let word = expand("<cword>")

        " add to list if not exists
        if count(b:cc_word_list, word) == 0 
            if a:backward
                call insert(b:cc_word_list, word)
            else
                call add(b:cc_word_list, word)
            endif
            return 1
        endif

        " search again
        let position = searchpos(pattern, flag)

    endwhile

    return 0 

endfunction

"-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" search other buffers
" return 0 if match none, else return 1 .
function! s:SearchBuffer(backward,bufindex)

    let pattern = '\<' . b:cc_word_prefix . '\w\+\>'

    while 1

        " get one line at once
        let bufline = getbufline(a:bufindex, b:cc_buffer_pos[0]) 

        " Eof detected !
        if len(bufline) == 0
            return 0 
        endif

        " start @ last position
        let text = strpart(bufline[0],b:cc_buffer_pos[1])
        let word = matchstr(text,pattern)

        if word == ""
            let b:cc_buffer_pos = [b:cc_buffer_pos[0]+1,0]
        else
            let b:cc_buffer_pos[1] += matchend(text,pattern)
            " add to list if not exists
            if count(b:cc_word_list, word) == 0 
                if a:backward
                    call insert(b:cc_word_list, word)
                else
                    call add(b:cc_word_list, word)
                endif
                return 1
            endif
        endif

    endwhile

    return 0 

endfunction

"-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" vim:sts=4:sw=4:ft=vim

