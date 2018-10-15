#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

function print_usage
{
	echo "Usage : "
	echo "${ME##*/}"
	echo "    -md=markdown_file"
	echo "    [-v] : verbose, print information to stdout."
	echo "    [-stdout] : print TOC to stdout."
	echo
	echo "First tag found '#' or '###' define main title."
	echo
}

typeset		md=undef
typeset		verbose=no
typeset		stdout=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-md=*)
			md=${1##*=}
			shift
			;;

		-v)
			verbose=yes
			shift
			;;

		-stdout)
			stdout=yes
			shift
			;;

		-h|-help|help)
			info "$(print_usage)"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$(print_usage)"
			exit 1
			;;
	esac
done

#ple_enable_log -params $PARAMS

exit_if_param_undef md	"$(print_usage)"

typeset	-r	TOC_separator="--------------------------------------------------------------------------------"
typeset	-r	TOC_title="Table of contents"

# Print to stdout "$@" with all back quotes removed.
function remove_backquotes
{
	tr -d \`<<<"$@"
}

# Print to stdout "$@" with all quotes removed.
function remove_quotes
{
	tr -d \'<<<"$@"
}

# Print to stdout "$@" with all slashs removed.
function remove_slashs
{
	tr -d \/<<<"$@"
}

# Print to stdout "$@" with all colons removed.
function remove_colons
{
	tr -d :<<<"$@"
}

# Print to stdout "$@" with all tods removed.
function remove_tods
{
	tr -d .<<<"$@"
}

# $@ string
# Simplify spaces and replace them by hyphens.
# Trailing spaces are removed.
# Print to stdout result.
function tr_spaces_by_hyphens
{
	typeset	-r res="$(tr '[:space:]' '-'<<<$(tr -s '[:space:]'<<<"$@"))"
	echo ${res:: -1} # Supprime l'espace de fin ajouté par la commande tr.
}

# Print to stdout markdown tags for title $@
function print_markdown_tags_for_title
{
	# Devrait être supprimé toutes les ponctuations ? Je n'ai pas trouvé de doc...
	typeset	-r	ref="$(to_lower						\
							$(tr_spaces_by_hyphens	\
								$(remove_colons		\
								$(remove_tods		\
								$(remove_slashs		\
								$(remove_quotes	"$@"	))))))"

	printf "* [%s](#%s)\n" "$@" "$ref"
}

# Print TOC to stdout for markdown $1
function print_TOC_for_markdown
{
	typeset	-r	md_file="$1"

	typeset	-i	first_marker_size=-1
	typeset	-i	backquoteX3_open=0		# Triple back quotes.
	typeset		line marker title

	while IFS= read line
	do
		if [[ $backquoteX3_open -eq 0 && "${line:0:1}" == "#" ]]
		then
			read marker title<<<"$(remove_backquotes $line)"
			if [ $first_marker_size -eq -1 ]
			then
				first_marker_size=${#marker}
				echo $TOC_title
				fill = ${#TOC_title}
				echo
			else #	Print title indentation.
				for (( i = 1; i <= $(( ${#marker} - first_marker_size )); ++i ))
				do
					printf "\t"
				done
			fi
			print_markdown_tags_for_title "$title"
		elif [ "${line:0:3}" == '```' ]
		then
			[ $backquoteX3_open -eq 0 ]	\
						&& ((++backquoteX3_open)) || ((--backquoteX3_open))
		fi
	done<"$md_file"

	echo
	echo $TOC_separator
	echo
}

# Remove TOC from markdown $@
function remove_TOC_from_markdown
{
	[ $verbose == yes ] && LN && line_separator || true

	if grep -qi "$TOC_title" "$@"	# Vérifie si le fichier contient bien le titre.
	then
		# Recherche le n° de ligne du séparateur $TOC_separator.
		typeset	-i	nr_line=$(grep -nE "^${TOC_separator}" "$@" | head -1 | cut -d: -f1)
		if [ $nr_line != 0 ]
		then
			# Si la ligne suivant le séparateur est vide, on l'efface aussi.
			[ x"$(head -$((nr_line+1)) "$@" | tail -1)" == x ] && ((++nr_line)) || true
			if [ $verbose == yes ]
			then
				info "Remove TOC from lines : #1 to #$nr_line."
				LN
			fi
			sed -i "1,${nr_line}d" "$@"
		else
			error "TOC separator not found !"
			LN

			info "Remove existing TOC manually."
			LN

			exit 1
		fi
	elif [ $verbose == yes ]
	then
		info "No TOC found for $(replace_paths_by_shell_vars "$@")"
		LN
	fi
}

exit_if_file_not_exists "$md"

if [ $stdout == yes ]
then
	if [ $verbose == yes ]
	then
		verbose=no
		warning "Warning : stdout enable ==> disable verbose mode."
		LN
	fi

	# Pour ne pas supprimer le TOC du md original, on travaille sur une copie.
	cp "$md" "/tmp/${md##*/}"
	md="/tmp/${md##*/}"
fi

remove_TOC_from_markdown "$md"

typeset		md_TOC="$md".$$
if [ $verbose == yes ]
then
	line_separator
	info "Gen TOC for $(replace_paths_by_shell_vars $md) to $(replace_paths_by_shell_vars $md_TOC)."
	LN
fi

print_TOC_for_markdown "$md" > "$md_TOC"

if [ $stdout != yes ]
then
	cat "$md" >> "$md_TOC"	# Concaténation du md original avec le TOC.
	mv "$md_TOC" "$md"
else
	cat "$md_TOC"
	rm "$md_TOC"
	rm "$md"				# C'est la copie qui est supprimée.
fi
