function! ToggleAllFolders()
	if (! exists ("b:toggle_all_folders_state"))
		" A l'ouverture du buffer les fonctions sont foldées.
		let b:toggle_all_folders_state = 'folded'
	endif

	if b:toggle_all_folders_state == 'folded'
		:echo "Functions unfolded"
		let b:toggle_all_folders_state='unfolded'
		normal! zR
	else
		:echo "Functions folded"
		let b:toggle_all_folders_state='folded'
		normal! zM
	endif
endfunction

function! CallBackVimFolding(line)
	if strpart( a:line, 0, strlen( 'function' ) ) == 'function'
		return '>1'
	endif

	if strpart( a:line, 0, strlen( 'endfunction' ) ) == 'endfunction'
		return '<1'
	endif

	return -1
endfunction

function! CallBackShellFolding(line)
	if a:line[0] == '{'
		return '>1'
	endif

	if a:line[0] == '}'
		return '<1'
	endif

	return -1
endfunction

function! EnableScriptFolding()
	let l:callBackPerso=1
	if &filetype == 'sh'
		"	Trop de bugs
		"set foldmethod=marker
		"set foldnestmax=1
		"	Pas bon fold toutes les lignes avec { ou }
		"set foldmarker={,}
		"	Ne marche pas
		"set foldmarker=^{,^}

		set foldexpr=CallBackShellFolding(getline(v:lnum))
		set foldmethod=expr
	elseif &filetype == 'vim'
		set foldexpr=CallBackVimFolding(getline(v:lnum))
		set foldmethod=expr
	else
		set foldmethod=manual
	endif
endfunction
