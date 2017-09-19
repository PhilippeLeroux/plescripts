#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-type=SINGLE|RAC|DATAGUARD
	-nodes=#    Value 1 for SINGLE, #member for RAC & DATAGUARD
	[-memory=#] Memory for VM (Mb)
	[-cpus=#]   #cpu for VM
"

typeset		type=undef
typeset	-i	nodes=-1
typeset		memory=undef
typeset		cpus=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-type=*)
			type=$(to_upper ${1##*=})
			shift
			;;

		-nodes=*)
			nodes=${1##*=}
			shift
			;;

		-memory=*)
			memory=${1##*=}
			shift
			;;

		-cpus=*)
			cpus=${1##*=}
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

exit_if_param_undef nodes "$str_usage"

exit_if_param_invalid type "SINGLE RAC DATAGUARD" "$str_usage"

if [[ "$memory" == undef && "$cpus" == undef  ]]
then
	error "Missing -memory or -cpus"
	LN
	exit 1
fi

typeset -ri host_memory=$(VBoxManage list hostinfo | grep "^Memory size:" | awk '{ print $3 }')
typeset -ri host_cpus=$(VBoxManage list hostinfo | grep "^Processor count:" | awk '{ print $3 }')

typeset -ri max_percent_of_host_memory=24

typeset	-ri max_memory_for_vm=$(compute -i "$host_memory-(($max_percent_of_host_memory * $host_memory)/100)")

info "Hypervisor : $(hostname -s)"
info "    Memory : $(fmt_number $host_memory) Mb, available for VMs $(fmt_number $max_memory_for_vm) Mb ($(( 100 - max_percent_of_host_memory))%)."
info "    cpu    : #$(fmt_number $host_cpus)"
LN

typeset -i errors=0

info "VM type $type #$nodes VMs"
if [ "$memory" != undef ]
then
	typeset -ri total_memory=$(( memory * nodes ))
	typeset -ri percent=$(compute -i "100 * $total_memory / $max_memory_for_vm")
	info -n "    VM memory $(fmt_number $memory) Mb, for #$nodes VMs $(fmt_number $total_memory) Mb, $(fmt_number $percent)% of $(fmt_number $max_memory_for_vm) Mb : "
	if [ $total_memory -le $max_memory_for_vm ]
	then
		info -f "[$OK]"
	else
		((++errors))
		info -f "[$KO]"
	fi
	if [ $memory -le $oracle_memory_mb_prereq ]
	then
		warning "    Warning Oracle prereq : $(fmt_number $oracle_memory_mb_prereq)Mb/VMs"
		LN
	fi
fi

if [ "$cpus" != undef ]
then
	info -n "    cpu #$cpus : "
	if [ $cpus -lt $host_cpus ]
	then
		info -f "[$OK]"
	elif [[ $cpus -eq $host_cpus && $nodes -gt 1 ]]
	then
		info -f " ${INVERT}warning : #cpu is high, same as hypervisor.${NORM}"
	else
		info -f "[$KO]"
		((++errors))
	fi
fi
LN

if [ $errors -ne 0 ]
then
	warning "VM settings can be ajusted with script ~/plescripts/update_local_cfg.sh"
	LN
	~/plescripts/update_local_cfg.sh -h
	exit 1
fi
