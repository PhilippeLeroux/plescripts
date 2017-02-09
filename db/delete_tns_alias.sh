#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -tnsalias=name"

script_banner $ME $*

typeset	tnsalias=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-tnsalias=*)
			tnsalias=$(to_upper ${1##*=})
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

exit_if_param_undef tnsalias "$str_usage"

typeset		alias_found=no
typeset -i	num=0
typeset		first_num
typeset		last_num=\$
typeset	-i	nr_closed=0
typeset	-i	nr_opened=0

[ ! -f $TNS_ADMIN/tnsnames.ora ] && exit 0 || true

#	Recherche le n° de ligne ou débute la définition de l'alias (first_num) et
#	le n° de ligne ou se termine la définition de l'alias (last_num)
#	Après la définition de l'alias on doit avoir une ligne vide ou la fin du
#	du fichier.
while read line
do
	num=num+1

	if [ $alias_found == no ]
	then
		if grep -qiE "${tnsalias}\s{0,}=.*"<<<"$line"
		then
			alias_found=yes
			first_num=$num
		fi
	else
		if [ x"$line" == x ]
		then # ligne vide, tout la définition a été lue.
			last_num=$num
			break
		fi

		typeset -i count=$(grep -o ")"<<<"$line"|wc -l)
		nb_closed=$(( nb_closed+count ))
		count=$(grep -o "("<<<"$line"|wc -l)
		nb_opened=$(( nb_opened+count ))
	fi
done<$TNS_ADMIN/tnsnames.ora

debug "alias_found = $alias_found"
if [ $alias_found == no ]
then
	info "Alias $tnsalias not found."
	exit 0
fi

debug "nb_opened - nb_closed = $nb_opened - $nb_closed = $(( nb_opened - nb_closed ))"
if [ $(( nb_opened - nb_closed )) -eq 0 ]
then
	info "Delete alias $tnsalias between lines $first_num & $last_num"
	cmd="'${first_num},${last_num}d'"
	exec_cmd sed -i $cmd $TNS_ADMIN/tnsnames.ora
else
	error "Alias found, failed to check lines"
	exit 1
fi
