function! TocMarkdown()
	execute ":w!"
	call system( 'markdown_toc.sh -md=' . shellescape(bufname("%")) )
	execute ":edit! %"
endfunction
