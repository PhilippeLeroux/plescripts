# vim: ts=4:sw=4

typeset	-a	usage_desc_list			# Mémorise les paramètres
typeset	-i	usage_max_len_desc=0
typeset	-a	usage_help_list			# Mémorise l'aide des paramètres.

#*> $1 option or new_line
#*> [$2] describe option.
function add_usage
{
	typeset	-r	usage_desc="$1"
	typeset	-ri	len=${#usage_desc}

	usage_desc_list+=( "$usage_desc" )
	if [ "$usage_desc" == new_line ]
	then
		usage_help_list+=( "none" )
	else
		[ $len -gt $usage_max_len_desc ] && usage_max_len_desc=$len || true

		[ $# -eq 2 ] && usage_help_list+=( "$2" ) || usage_help_list+=( "none" )
	fi
}

#*> Print to stdout all messages
function print_usage
{
	for (( i=0; i < ${#usage_desc_list[@]}; i++ ))
	do
		if [ "${usage_desc_list[i]}" == new_line ]
		then
			echo
		else
			printf "    %-${usage_max_len_desc}s" "${usage_desc_list[i]}"
			if [ "${usage_help_list[i]}" == "none" ]
			then # Pour passer à la ligne
				echo
			else # Affiche la description et passe à la ligne.
				echo " ${usage_help_list[i]}"
			fi
		fi
	done
}

#*> Reset internals variables.
function reset_usage
{
	usage_desc_list=()
	usage_max_len_desc=0
	usage_help_list=()
}

