"	return number of elements for list
function! CountListElt( list )
	let l:nr = 0

	while get( a:list, nr, "none" ) != "none"
		let l:nr = nr + 1
	endwhile

	return nr
endfunction

"	Print (echo) all files within fileList with number selection.
function! PrintFileSelectionNumber( nrElt, fileList )
	echo 'Files found :'

	let l:idx = 0

	while idx < a:nrElt
		echo idx + 1 . ' : ' . a:fileList[ idx ]

		let l:idx = idx + 1
	endwhile
endfunction

"	Ask to user the file name to open.
"	Return index of file to open from fileList, -1 if cancelled.
function! AskUserIdxFileNameToOpen( nrElt, fileList )
	while 1 == 1
		call PrintFileSelectionNumber( a:nrElt, a:fileList )

		call inputsave()
		let l:nrFile = input( 'Select file number to open (0 cancel) : ', 1 )
		call inputrestore()

		if nrFile == 0
			return -1
		elseif nrFile > 0 && nrFile <= a:nrElt
			return nrFile - 1
		endif

		echo '.'
		echo 'Number ' . nrFile . ' invalid.'
	endwhile
endfunction

"	Search fileName in directory : g:SearchAndOpenFileUnderTheCursorDir
"	return
"		- full name path of fileName.
"		- empty string if no file found.
"		- Cancelled if user cancel.
function! SearchFullNamePathFor( fileName )
	" findfile ne fonctionne pas si plusieurs fichiers sont trouvés.
	" Cf test en fin du script.
	let l:list = system( 'find ' . g:SearchAndOpenFileUnderTheCursorDir
								\	. ' -type f  -name "' . a:fileName . '"' )

	if list == ''
		return ''
	else
		let l:fileList = split( list )
		let l:nrElt = CountListElt( fileList )

		if nrElt == 1
			return fileList[ 0 ]
		else
			let l:idxFile = AskUserIdxFileNameToOpen( nrElt, fileList )

			if idxFile == -1
				return 'Cancelled'
			else
				return fileList[ idxFile ]
			endif
		endif
	endif
endfunction

"	return
"		- Opened, if file is open.
"		- Not opened, if file not found.
"		- Cancelled, if user cancel.
function! AssignmentBug( wordUnderCursor )
	" vim 7.x bug ? :
	" Affectation d'une variable, ex : var=~/fileName
	let l:fileList = split( a:wordUnderCursor, '=' )

	let l:fileName = expand( get( fileList, 1, "none" ) )

	if filereadable( fileName )
		exe ':sp ' . fileName
		return 'Opened'
	else
		let l:fullNamePath = SearchFullNamePathFor( fileName )

		if fullNamePath == ''
			return 'Not opened'
		elseif fullNamePath == 'Cancelled'
			return 'Cancelled'
		else
			exe ':sp ' . fullNamePath
			return 'Opened'
		endif
	endif
endfunction

" Si la variable g:SearchAndOpenFileUnderTheCursorDir n'est pas définie, la
" recherche se fait dans $HOME
function! SearchAndOpenFileUnderTheCursor()
	if ! exists( 'g:SearchAndOpenFileUnderTheCursorDir' )
		let g:SearchAndOpenFileUnderTheCursorDir=$HOME
	endif

	" Le premier expand : résout les variables d'environnement.
	" Le second expand : expand to full path
	let l:wordUnderCursor = expand( expand( "<cfile>:p" ) )

	if filereadable( wordUnderCursor  )
		exe ':sp ' . wordUnderCursor
	else
		let l:wordUnderCursor = expand( "<cfile>" )

		if strpart( wordUnderCursor, 0, 2 ) == './'
			let l:wordUnderCursor = strpart( wordUnderCursor, 2 )
		endif

		let l:fullNamePath = SearchFullNamePathFor( wordUnderCursor )

		if fullNamePath == 'Cancelled'
			return
		elseif fullNamePath == ''
			if AssignmentBug( wordUnderCursor ) == 'Not opened'
				echo 'File ' . wordUnderCursor . ' not found in directory '
						\	. g:SearchAndOpenFileUnderTheCursorDir . '.'
			endif
		else
			exe ':sp ' . fullNamePath
		endif
	endif
endfunction

function! TestFindFile()
	" Bug vim 7.X ?
	let l:fileList=findfile( 'validate_config.sh', expand( g:SearchAndOpenFileUnderTheCursorDir ) )
	echo 'validate_config.sh présent 1 fois OK : ' . fileList
	" Copier le fichier markdown_toc.sh dans g:SearchAndOpenFileUnderTheCursorDir/tmp
	let l:fileList=findfile( 'markdown_toc.sh', expand( g:SearchAndOpenFileUnderTheCursorDir ) )
	echo 'markdown_toc.sh présent plus de 1 fois KO : ' . fileList
	" Même si {count} est négatif, la list est vide :
	echo findfile( 'markdown_toc.sh', expand( g:SearchAndOpenFileUnderTheCursorDir ), -1 )
endfunction
"nnoremap <leader>t :call TestFindFile()<CR>
