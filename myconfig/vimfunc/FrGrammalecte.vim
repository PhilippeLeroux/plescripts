let g:grammalecte_cli_py='$HOME/Grammalecte/cli.py'
function! FrGrammalecte()
	if (! exists ("b:grammar_is"))
		let b:grammar_is = 'no'
	endif

	if b:grammar_is == 'no'
		let b:grammar_is='fr'
		:GrammalecteCheck
	elseif b:grammar_is == 'fr'
		let b:grammar_is='no'
		:GrammalecteClear
	endif
endfunction
