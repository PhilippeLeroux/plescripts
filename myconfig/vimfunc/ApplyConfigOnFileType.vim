"	Test si un fichier est de type 'code source', si c'est le cas adapte la
"	configuration :
"		- marge
"		- n° de ligne.
"		- linebreak
function! ApplyConfigOnFileType()
	if &filetype == '' && getline(1) =~ '#!.*sh'
		set filetype=sh
	endif

	if g:first_load == 0
		return
	endif

	if	&filetype == 'sh' || &filetype == 'c' || &filetype == 'cpp'
	\	|| &filetype == 'cfg' || &filetype == 'markdown' || &filetype == 'vim'
	\	|| &filetype == 'sql'
		let l:type_source='yes'
	else
		let l:type_source='no'
	endif

	if l:type_source == 'yes'
		if has("gui_running" )
			set cc=81 nonu nowrap
		else
			set cc=81 nonu nowrap linebreak
		endif
	elseif &filetype == 'man'
		set cc=0 nonu nowrap
	else
		if expand('%:t') == 'COMMIT_EDITMSG'
			set cc=75 nonu nowrap
		else
			if has("gui_running" )
				set cc=0 nonu nowrap
			else
				set cc=0 nonu nowrap
			endif
		endif
	endif
endfunction
