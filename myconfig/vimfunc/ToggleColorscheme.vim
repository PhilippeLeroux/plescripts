" Pour le thème par défaut les variables d'environnements GVIM_COLORSCHEME et
" VIM_COLORSCHEME sont lues. Elles permettent de choisir entre un thème clair
" ou sombre.
" Les valeurs possibles sont :
"	- dark
"	- light
"	- none pour ne pas appliquer de thème.

function! SpellSettings()
	" Améliore considérablement la lisibilité.
	highlight clear SpellBad
	highlight SpellBad term=standout ctermfg=1 term=underline cterm=underline
	highlight clear SpellCap
	highlight SpellCap term=underline cterm=underline
	highlight clear SpellRare
	highlight SpellRare term=underline cterm=underline
	highlight clear SpellLocal
	highlight SpellLocal term=underline cterm=underline
endfunction

function! ToggleColorscheme()
	if g:colors_name == g:dark_colors_name
		execute "colorscheme ".g:light_colors_name
	else
		execute "colorscheme ".g:dark_colors_name
	endif

	if !has("gui")
		call SpellSettings()
	endif
endfunction

if has("gui_running")
	" Nom des thèmes installés.
	let g:light_colors_name = 'github'
	let g:dark_colors_name = 'sourcerer'

	if plewiki_directory == 'yes'
		" Markdown je préfère claire, car mon navigateur est claire.
		let g:colors_name = g:light_colors_name
	else
		if $GVIM_COLORSCHEME == 'light'
			let g:colors_name = g:light_colors_name
		elseif $GVIM_COLORSCHEME == 'dark' || $GVIM_COLORSCHEME == '' || $VIM_COLORSCHEME == 'none'
			let g:colors_name = g:dark_colors_name
		endif
	endif

	set guifont=Monospace\ 11
	set guioptions+=b
else
	let g:light_colors_name = 'github'
	let g:dark_colors_name = 'sourcerer'

	if $HOSTNAME =~# 'K2.*'
		" Le terminal de K2 est sombre
		let g:colors_name = g:dark_colors_name
	else
		" Sur ma machine le terminal est claire.
		if $VIM_COLORSCHEME == 'light' || $VIM_COLORSCHEME == '' || $VIM_COLORSCHEME == 'none'
			let g:colors_name = g:light_colors_name
		elseif $VIM_COLORSCHEME == 'dark'
			let g:colors_name = g:dark_colors_name
		endif
	endif
endif

if g:first_load == 1
	" Les couleurs sont switchées par la fonction ToggleColorscheme
	" donc inversion des couleurs avant l'appel.
	if g:colors_name == g:dark_colors_name
		let g:colors_name=g:light_colors_name
	else
		let g:colors_name=g:dark_colors_name
	endif

	if has("gui_running")
		if $GVIM_COLORSCHEME != 'none'
			call ToggleColorscheme()
		endif
	else
		if $VIM_COLORSCHEME != 'none'
			call ToggleColorscheme()
		endif
	endif
endif
