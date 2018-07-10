#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : ${ME##*/} <libname>
Compte le nombre de fois qu'une fonction de la lib <libname> est utilisée dans un
script.

Ex : ${0##*/} ~/plescripts/plelib.sh
"

typeset libname=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			if [ "$libname" != undef ]
			then
				error "Paramètre $1 invalide."
				LN
				info "$str_usage"
				exit 1
			fi

			libname="$1"
			shift
			;;
	esac
done

exit_if_param_undef libname	"$str_usage"

if [ ! -f "$libname" ]
then
	error "$libname not exists."
	LN
	info "$str_usage"
	exit 1
fi

typeset -r all_exec_files=/tmp/tempo.$$
find ~/plescripts -perm /u=x -type f -or -name "*lib.sh" > $all_exec_files

info "Nombre de scripts utilisant une fonction de $libname :"
while read keyword func_name rem
do
	typeset -i nr_file=0
	while read file_name
	do
		if [ "$file_name" != "$libname" ]
		then
			grep -q "$func_name" "$file_name" && ((++nr_file)) || true
		fi
	done<$all_exec_files

	if [ $nr_file -eq 0 ]
	then
		# Si la fonction est présente plus de 1 fois dans $libname, c'est
		# qu'elle est utilisée par $libname mais pas par d'autre scripts.
		typeset -i v=$(grep "$func_name" "$libname" | wc -l)
		[ $v -gt 1 ] && nr_file=1 || true
	fi

	printf "%3d %s\n" $nr_file $func_name
done<<<"$(grep "^function" "$libname")" | sort -rn

rm -rf $all_exec_files >/dev/null 2>&1
