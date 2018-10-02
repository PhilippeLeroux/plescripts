function! ToggleVimTips()
	if ! exists( "g:vimtips" )
		let g:vimtips='off'
	endif

	if g:vimtips == "on"
		let g:vimtips="off"
		pclose
	else
		let g:vimtips="on"
		set previewheight=5
		pedit! ~/vimfunc/vimtips
	endif
endfunction
