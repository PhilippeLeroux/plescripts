" Utilisé uniquement si la version de vim est inférieur à 704.
" Sinon c'est grammalecte qui est utilisé car plus pratique.
let g:grammarous#disabled_rules = {
	\ '*' : ['FRENCH_WHITESPACE,WHITESPACE_RULE,FIXTURE,EMAIL,HUNSPELL_NO_SUGGEST_RULE'],
	\ 'help' : ['WHITESPACE_RULE', 'EN_QUOTES', 'SENTENCE_WHITESPACE', 'UPPERCASE_SENTENCE_START'],
	\ }
function! FrGrammaire()
	if (! exists ("b:grammar_is"))
		let b:grammar_is = 'no'
	endif

	if b:grammar_is == 'us'
		let b:grammar_is='no'
		:LanguageToolClear
	endif

	:GrammarousReset

	if b:grammar_is == 'no'
		:echo "Grammaire française activée."
		let b:grammar_is='fr'
		if ( &filetype == 'sh' )
			:GrammarousCheck --lang=fr --comments-only
		else
			:GrammarousCheck --lang=fr --no-comments-only
		endif
	elseif b:grammar_is == 'fr'
		:echo "Grammaire française désactivée."
		let b:grammar_is='no'
	endif
endfunction
