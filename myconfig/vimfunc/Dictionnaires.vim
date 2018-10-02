"	Si aucun dictionnaire actif, active le dictionnaire Fr.
"	Si dictionnaire Fr actif, désactive le dictionnaire.
function! FrDictionnaire()
	if (! exists ("b:dictionnary_is"))
		let b:dictionnary_is = 'no'
	endif

	if b:dictionnary_is == 'us'
		let b:dictionnary_is='no'
		:setlocal nospell
	endif

	if b:dictionnary_is == 'no'
		:echo "Dictionnaire français."
		let b:dictionnary_is='fr'
		:setlocal spell spelllang=fr
	elseif b:dictionnary_is == 'fr'
		:echo "Dictionnaire désactivé."
		let b:dictionnary_is='no'
		:setlocal nospell
	endif
endfunction

"	Si aucun dictionnaire actif, active le dictionnaire US.
"	Si dictionnaire US actif, désactive le dictionnaire.
function! USDictionnaire()
	if (! exists ("b:dictionnary_is"))
		let b:dictionnary_is = 'no'
	endif

	if b:dictionnary_is == 'fr'
		let b:dictionnary_is='no'
		:setlocal nospell
	endif

	if b:dictionnary_is == 'no'
		:echo "Dictionnaire US."
		let b:dictionnary_is='us'
		:setlocal spell spelllang=en_us
	elseif b:dictionnary_is == 'us'
		:echo "Dictionnaire désactivé."
		let b:dictionnary_is='no'
		:setlocal nospell
	endif
endfunction
