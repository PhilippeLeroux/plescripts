#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Oblige le serveur $(hostname -s) à se mettre à jours uniquement sur ${infra_hostname}"

info "Running : $ME $*"

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
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

line_separator
info "Désactive le dépôt du net sur $(hostname -s)."
typeset -ri last_line=$(wc -l /etc/yum.repos.d/public-yum-ol7.repo | cut -d' ' -f1)
exec_cmd sed -i "${last_line}s/enabled=1/enabled=0/" /etc/yum.repos.d/public-yum-ol7.repo
LN
