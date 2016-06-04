#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

hdump="od -A x -t x1z -v"

typeset -r msg=\
"Ligne 1
Ligne 2
Ligne 3"

clear
echo $msg | $hdump
LN
printf "$msg" | $hdump
LN

info "Affichage avec echo"
echo $msg
LN

info "Affichage avec printf"
printf "$msg\n"
LN

info "Affichage avec info"
info "$msg"
LN


