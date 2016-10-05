# vim: ts=4:sw=4

#	############################################################################
#	Contient toutes les fonctions qui ont été utilisées mais qui ne le sont plus.
#	############################################################################

#*>	$1 max len
#*>	$2 string
#*>
#*>	Si la longueur de string est supérieur à max len alors
#*>	string est raccourcie pour ne faire que max len caractères.
#*>
#*>	Par exemple
#*>				XXXXXXXXXXXXXXXXXXX
#*>	deviendra	XXX...XXX
function shorten_string
{
	typeset -i	max_len=$1
	typeset -r	string=$2
	typeset -ri	string_len=${#string}

	if [ $string_len -gt $max_len ]
	then
		max_len=max_len-3 #-3 pour les ...
		typeset -ri	car_to_remove=$(compute -i "($string_len - $max_len)/2")
		typeset -ri begin_len=$(compute -i "$string_len / 2 - $car_to_remove")
		typeset -ri end_start=$(compute -i "$string_len - ( $string_len / 2 - $car_to_remove )" )
		comp="${string:0:$begin_len}...${string:$end_start}"
		echo "$comp"
	else
		echo $string
	fi
}

#*> $1 gap		(si non précisé vaudra 0)
#*> $2 string
function string_fit_on_screen
{
	typeset -i	gap=1
	typeset 	string="$1"
	if [ $# -eq 2 ]
	then
		gap=$1
		string="$2"
	fi

	typeset -i len=$(term_cols)
	len=len-gap

	shorten_string $len "$string"
}

#*> D'après mes scripts where_is_used et lib_func_usage.sh la fonction n'est
#*> plus utilisée. Comme je suis convaincu l'avoir vue récemment dans un script
#*> et que je remets en doute mes talents de scripteur je garde au cas ou.
#*> Ajout : 31/08/2016
#*> return string :
#*>	  true	if $1 in( y, yes )
#*>   false if $1 in( n, no )
function yn_to_bool
{
	case $1 in
		y|yes)	echo true
				;;

		n|no)	echo false
				;;
	esac
}
