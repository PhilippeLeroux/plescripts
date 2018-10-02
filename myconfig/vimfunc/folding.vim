"	Fold/Unfold les fonctions d'un script shell,
"	Je déclare mes fonctions comme ca :
"	function foo
"	{
"		code
"	}
"	Donc si un accolade ouvrante est trouvée je marque le début du fold, si
"	une accolade fermante est trouvée je marque la fin du fold.

"	Fold/Unfold toutes les fonctions présente dans le script.
"	TODO : comment unfolder que le premier niveau ??
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

function! FirstNonBlankChar(for_line)
	let l:i=0
	while a:for_line[l:i] == ' ' || a:for_line[l:i] == '	'
		let l:i=l:i+1
	endwhile

	return a:for_line[l:i]
endfunction

function! CallBackShellFoldingV3(line)
	if (! exists ("b:fold_level"))
		let b:fold_level=foldlevel(v:lnum)
	else
		let b:fold_level=foldlevel(v:lnum-1)
	endif
	echom &b:fold_level

	let l:first_char=FirstNonBlankChar(a:line)

	if l:first_char == '{'
		let b:fold_level=b:fold_level+1
		return '>'.b:fold_level				"	Open fold at level fold_level
	elseif l:first_char == '}'
		if b:fold_level == 0
			return '='						"	BUG de mes 'heredoc rman'
		endif

		let l:mark='<'.b:fold_level			"	Clode fold at level fold_level
		let b:fold_level=b:fold_level-1
		return l:mark
	elseif b:fold_level == 0
		" return '=' fait foirer le folding, si par exemple une ligne et
		" supprimée suivit d'un undo.
		return 	'='							"	No folding
	else
		return 	'='							"	fold level of previous line.
	endif
endfunction

"	Pas encore fiable à 100%
"	Cas fonctions incluse : modifier le code fait perdre ces marques de
"	folding, toutes les fonctions en dessous ne peuvent plus être foldées,
"	parfois c'est uniqement la fonction en cour de modification.
function! CallBackShellFoldingV2(line)
	if (! exists ("b:fold_level"))
		let b:fold_level=0
	endif

	let l:first_char=FirstNonBlankChar(a:line)

	if l:first_char == '{'
		let b:fold_level=b:fold_level+1
		return '>'.b:fold_level				"	Open fold at level fold_level
	elseif l:first_char == '}'
		if b:fold_level == 0
			return '='						"	BUG de mes 'heredoc rman'
		endif

		let l:mark='<'.b:fold_level			"	Clode fold at level fold_level
		let b:fold_level=b:fold_level-1
		return l:mark
	elseif b:fold_level == 0
		" return '=' fait foirer le folding, si par exemple une ligne et
		" supprimée suivit d'un undo.
		return 	'-1'						"	No folding
	else
		return 	'='							"	fold level of previous line.
	endif
endfunction

"	Les fonctions sont foldées au niveau de l'accolade.
"	Les functions déclarées dans les functions ne sont pas prise en compte.
function! CallBackShellFolding(line)
	if a:line[0] == '{'
		return '>1'
	endif

	if a:line[0] == '}'
		return '<1'
	endif

	return -1
endfunction

function! EnableShellFoldBrace()
	if &filetype == 'sh'
		"set foldexpr=CallBackShellFoldingV2(getline(v:lnum))
		set foldexpr=CallBackShellFolding(getline(v:lnum))
		set foldmethod=expr
	else
		set foldmethod=manual
	endif
endfunction
