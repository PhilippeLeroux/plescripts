#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -alias_name=name"

info "Running : $ME $*"

typeset	alias_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-alias_name=*)
			alias_name=$(to_upper ${1##*=})
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

exit_if_param_undef alias_name "$str_usage"

exit_if_file_not_exist $TNS_ADMIN/tnsnames.ora

typeset		alias_found=no
typeset -i	num=0
typeset		first_num
typeset		last_num=\$
typeset	-i	nr_closed=0
typeset	-i	nr_opened=0

while read line
do
	num=num+1

	if [ $alias_found == no ]
	then
		if [[ $line == ${alias_name}* ]]
		then
			alias_found=yes
			first_num=$num
		fi
	else
		if [ x"$line" == x ]
		then
			last_num=$num
			break
		fi

		typeset -i count=$(grep -o ")"<<<"$line"|wc -l)
		nb_closed=$(( nb_closed+count ))
		count=$(grep -o "("<<<"$line"|wc -l)
		nb_opened=$(( nb_opened+count ))
	fi
done<$TNS_ADMIN/tnsnames.ora

if [ $(( nb_opened - nb_closed )) -eq 0 ]
then
	info "$alias_name found between $first_num & $last_num"
	exec_cmd sed '${first_num},${last_num}d' $TNS_ADMIN/tnsnames.ora
else
	warning "$alias_name not found."
fi
