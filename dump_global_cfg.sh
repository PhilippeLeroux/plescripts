#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME ...."

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
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

#ple_enable_log -params $PARAMS

typeset	-r	output=/tmp/dump_global_cfg.$$

while read varname
do
	info -n "$varname = ${!varname}"
	if [ "${!varname}" == "" ]
	then
		info -f "${RED}${BLINK}ERROR${NORM}"
	else
		LN
	fi
done<<<"$(grep -E "^\s{0,}typeset" ~/plescripts/global.cfg	\
	|	sed "s/typeset\s\(-r\(i\)\{0,1\}\)\{0,1\}\s\(.*\)=.*/\3/g")" \
	|	sort|uniq > $output

typeset -ri nr_var=$(cat $output|wc -l)
cat $output
LN

info -n "Variables : $nr_var"
LN
