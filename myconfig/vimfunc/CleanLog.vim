"	Nettoie tous les caractères d'affichage (couleur & co)
function! CleanLog()
	if expand('%:t:r')
		call system('clean_log ' . shellescape(bufname("%")))
		execute ":e%"
	endif
endfunction
