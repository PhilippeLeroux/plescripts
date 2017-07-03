#!/bin/bash
# vim: ts=4:sw=4

#	Utilisé par la fonction SearchFunctionLib dans vimrc.

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-script=script_name	script ou chercher la fonction.
	-funcName=func_name nom de la fonction à chercher.

Recherche dans les scripts de type lib inclues dans 'script_name' la fonction 'func_bame'.
Un script de type lib est de la forme : . .*lib.sh

Si la fonction est trouvée affiche sur la sortie standard le n° de ligne suivit
du nom du script.
Sinon affiche le message : not found
"

typeset script=undef
typeset funcName=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-script=*)
			script=${1##*=}
			shift
			;;

		-funcName=*)
			funcName=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef script	"$str_usage"
exit_if_param_undef funcName	"$str_usage"

debug "Load all lib..."
typeset -r inc_file_list=$(grep "^\. .*lib.sh" $script | xargs)
debug "Lib list : $inc_file_list"

[ x"$inc_file_list"x == x ] && exit 1

for lib in $inc_file_list
do
	[ "$lib" == "." ] && continue
	lib=$(sed "s!^~!$HOME!" <<< "$lib")
	debug "Search : $lib"
	debug "	grep -En \"function $funcName\\s{0,}\$\" $lib"
	res=$(grep -En "function $funcName\\s{0,}\$" $lib)
	if [ $? -eq 0 ]
	then
		debug "res = '$res'"
		echo $(cut -d\: -f1 <<<"$res") $lib 
		exit 0
	fi	
done

echo -n "not found"
exit 1
