function! GotoDir( dir_name )
	echo "cd ".a:dir_name

	execute "cd ".a:dir_name
	execute "NERDTree ".a:dir_name
	wincmd p	"Go to previous windows
endfunction

function! Goto_plescripts()
	:call GotoDir( '$HOME/plescripts' )
endfunction

function! Goto_oracle_bash_completion()
	:call GotoDir( '$HOME/oracle_bash_completion' )
endfunction

function! Goto_home()
	:call GotoDir( '$HOME' )
endfunction

