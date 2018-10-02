"	============================================================================
"	Recherche de la fonction correspondante dans une des libs inclusent dans
"	le fichier source.
"	Le script shell vimsearchfunc.sh est utilisé.
function! SearchFunctionLib( func )
	let l:res = system( 'vimsearchfunc.sh -script=' . shellescape(bufname("%")) . ' -funcName=' . a:func )
	if l:res == 'not found'
		return 1
	else
		let l:sp = split( l:res )
		exe 'pedit +' . l:sp[0] . ' ' . l:sp[1]
		return 0
	endif
endfunction

"	============================================================================
"	Recherche dans le script et dans les libs inclusent par le script la
"	définition de la fonction sous le curseur.
"
"	Mapper la fonction sur une touche, par exemple
"	nnoremap <leader>f :call SearchFunction()<CR>
function! SearchFunction()
	let l:wordUnderCursor = expand("<cword>")
	let l:funcPattern="^function " . l:wordUnderCursor
	if search( l:funcPattern, 'b' ) == 0
		if search( l:funcPattern ) == 0
			if SearchFunctionLib( l:wordUnderCursor ) != 0
				echo "Function '" . l:wordUnderCursor . "' not found"
			endif
		endif
	endif
endfunction
