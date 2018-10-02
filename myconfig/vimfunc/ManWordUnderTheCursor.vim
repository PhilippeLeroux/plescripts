function! ManWordUnderTheCursor()
	let l:wordUnderCursor = expand("<cword>")
	execute "Man " . l:wordUnderCursor
endfunction
