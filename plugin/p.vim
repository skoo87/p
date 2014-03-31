
let Project_Has_Been_Created = 0

"-------------------------------------------------------------------------------
"                                   function
"-------------------------------------------------------------------------------
"
function! Do_CsTagWithArgs(dir, tag, bg)
    if(executable('ctags'))
        let my_ctag = "/opt/local/bin/ctags"
        let my_opt = "-R --sort=yes --languages=c --c-kinds=+px --fields=+iaKSz --extra=+q --language-force=c"
        let my_cmd = my_ctag . " " . my_opt . " -f " . a:tag . " " . a:dir

        if a:bg == 0
            echo printf("Start to execute ctags cmd: \"%s\"", my_cmd)
        endif

        let ret = xolox#shell#execute(my_cmd, 0)
        if ret == 0
            echo printf("ERROR: \"%s\"", my_cmd)
        else
            if a:bg == 0
                echo printf("DONE: \"%s\"", my_cmd)
            endif 
        endif
    endif

    unlet! my_ctag
    unlet! my_opt
    unlet! my_cmd
endfunction

function! Do_Ctags_Libs(dirs)
    echo "LIBS: " . a:dirs

    try
        if (!isdirectory(".vim_tags"))
            call mkdir(".vim_tags")
        endif

        call Do_CsTagWithArgs(a:dirs, ".vim_tags/libs.tag", 0)
    catch
        echo "ERROR: \".vim_tags\" may be a file..."
    endtry
endfunction

function! Do_Ctags_Project(dirs)
    echo "PROJECT: " . a:dirs

    try
        if (!isdirectory(".vim_tags"))
            call mkdir(".vim_tags")
        endif

        call Do_CsTagWithArgs(a:dirs, ".vim_tags/tags", 0)
    catch
        echo "ERROR: \".vim_tags\" may be a file."
    endtry
endfunction


function! Update_Ctags_Project(dirs)
    let l:cur_time = localtime()
    if exists('s:update_tags_time') && l:cur_time >= s:update_tags_time 
                \ && l:cur_time - s:update_tags_time < 5 
        return
    endif

    let s:update_tags_time = l:cur_time

    try
        if (!isdirectory(".vim_tags"))
            call mkdir(".vim_tags")
        endif

        call Do_CsTagWithArgs(a:dirs, ".vim_tags/tags", 1)
    catch
        echo "ERROR: \".vim_tags\" may be a file..."
    endtry
endfunction


function! s:Init_Working_dir(conf_dir)
    set noautochdir

    if empty(a:conf_dir) || a:conf_dir == "."
        let s:working_dir = getcwd()
    else
        let s:working_dir = a:conf_dir
    endif

    execute "lcd" . " " . s:working_dir

    echo "INFO: \"working_dir\" setting successfully - " . s:working_dir
endfunction


function! s:Init_Code_Dir()
    let l:p = 0
    let l:l = 0

    try
        let l:conf_cnt = readfile(".vim.ini")
    catch
        echo "ERROR: Don't have \".vim.ini\" in \"" . s:working_dir . "\""
        return -1
    endtry

    for line in l:conf_cnt
        if empty(line)
            continue
        endif

        if line == "[project]"
            let l:p = 1
            let l:l = 0
        elseif line == "[libs]"
            let l:p = 0
            let l:l = 1
        elseif l:p == 1 
            call add(s:project, line)
        elseif l:l == 1
            call add(s:libs, line)
        else
            echo "ERROR CONF: " . line
        endif
    endfor

    return 0
endfunction


function! s:Get_All_Project_Code_Dirs()
    let l:dir = ""

    for p in s:project
        if (!isdirectory(p))
            echo 'ERROR: not have "' . p . '" directory in "' . s:working_dir . 
                        \ '", please check ".vim.ini"' 
            return ""
        endif

        let l:tmp = s:working_dir . '/' . p
        let l:dir = l:dir . " " . l:tmp
    endfor

    return l:dir
endfunction


function! s:Get_All_Libs_Code_Dirs()
    let l:dir = ""

    for l in s:libs
        if (!isdirectory(l))
            echo "ERROR: \"" . l . "\" is not a directory, please check \".vim.ini\""
            return ""
        endif

        let l:dir = l:dir . " " . l
    endfor

    return l:dir
endfunction


function! s:Reset_All_Var() 
    let Project_Has_Been_Created = 0

    let s:working_dir = ""
    let s:project = []
    let s:libs = []
    let s:project_code_dirs = ""
endfunction


"------------------------------------------------------------------------------
"                            start function
"------------------------------------------------------------------------------
"
function! Load_My_Project(dir)

    call s:Reset_All_Var()

    call s:Init_Working_dir(a:dir)

    if empty(s:working_dir)
        echo "ERROR: init the \"working_dir\" failed."
        return
    endif


    let l:res = s:Init_Code_Dir()
    if l:res == -1
        echo "ERROR: init code directory failed."
        return
    endif
    
    let l:libs_dir = s:Get_All_Libs_Code_Dirs()
    if !empty(l:libs_dir)
        call Do_Ctags_Libs(l:libs_dir)
    else
        echo "WARN: not have libs code directory."
    endif

    let l:pro_dir = s:Get_All_Project_Code_Dirs()
    if empty(l:pro_dir)
        echo "ERROR: not have project code directory"
        return
    endif

    " set tags file
    "
    call Do_Ctags_Project(l:pro_dir)
    set tags=.vim_tags/libs.tag,.vim_tags/tags
    set tags

    " set file tags
    "
    call system("gen-file-tags")
    let g:LookupFile_TagExpr = '"./.vim_tags/file_tags"'

    " define command to update project's tags
    "
    let s:project_code_dirs = l:pro_dir
    if !empty(s:project_code_dirs)
        command! UpdateMyProject :call Do_Ctags_Project(s:project_code_dirs)
        
        autocmd BufWritePost,FileWritePost *.[ch] :call Update_Ctags_Project(s:project_code_dirs) 
    endif

    let Project_Has_Been_Created = 1
endfunction


" define my command to start the project
"
command! -complete=file -nargs=1 StartMyProject :call Load_My_Project(<f-args>)
command! -nargs=0 DelSpace :% s/\s\+$//g
command! -nargs=0 DelTab :ret! 4
