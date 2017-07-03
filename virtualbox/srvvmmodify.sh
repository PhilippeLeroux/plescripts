#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
	$ME '--x2apic off'
	$ME '--x2apic on'

Applique l'option à toutes les VMs dont le nom commence par srv.
"

typeset option=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			if [ "$option" != undef ]
			then
				error "1 seule option."
				LN
				info "$str_usage"
				LN
				exit 1
			fi
			option="${1##*=}"
			shift
			;;
	esac
done

exit_if_param_undef option	"$str_usage"

typeset -a vm_list

while read vm_name
do
	[ x"$vm_name" == x ] && continue || true

	vm_list+=( $vm_name )
done<<<"$(VBoxManage list vms | grep -E "^\"srv" | cut -d\" -f2)"

for vm_name in ${vm_list[*]}
do
	exec_cmd VBoxManage modifyvm $vm_name $option
done
