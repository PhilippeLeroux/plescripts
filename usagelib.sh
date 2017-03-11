# vim: ts=4:sw=4

typeset	-a	usage_desc_list			# Mémorise les paramètres
typeset	-i	usage_max_len_desc=0
typeset	-a	usage_help_list			# Mémorise l'aide des paramètres.

#*> $1 option
#*> $2 describe option (optional)
function add_usage
{
	typeset	-r	usage_desc="$1"
	typeset	-ri	len=${#usage_desc}

	usage_desc_list+=( $usage_desc )
	[ $len -gt $usage_max_len_desc ] && usage_max_len_desc=$len || true
	if [ $# -eq 2 ]
	then
		usage_help_list+=( "$2" )
	else
		usage_help_list+=( "none" )
	fi
}

function print_usage
{
	for (( i=0; i < ${#usage_desc_list[@]}; i++ ))
	do
		printf "\t%-${usage_max_len_desc}s" ${usage_desc_list[i]}
		if [ "${usage_help_list[i]}" == "none" ]
		then
			echo
		else
			echo " ${usage_help_list[i]}"
		fi
	done
}

function reset_usage
{
	usage_desc_list=()
	usage_max_len_desc=0
	usage_help_list=()
}

