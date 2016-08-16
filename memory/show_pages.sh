#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

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

if [ -v ORACLE_SID ]
then
	if [ "${ORACLE_SID:${#ORACLE_SID}-2:1}" == "_" ]
	then # Policy Managed or One Node
		typeset base=$(to_lower ${ORACLE_SID%_*})
	else
		typeset base=$(to_lower "${ORACLE_SID:0:${#ORACLE_SID}-1}")
	fi
	typeset -r alog="/u01/app/oracle/diag/rdbms/${base}*/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
	if [ -f $alog ]
	then
		line_separator

		typeset -i	available_pages expected_pages allocated_pages
		read page_size_kb available_pages expected_pages allocated_pages errors <<<$(grep "^     2048K" $alog | tail -1)

		typeset	-ri	page_size_b=$(convert_2_bytes $page_size_kb)

		typeset -ri	available_pages_size=available_pages*page_size_b
		typeset -ri	expected_pages_size=expected_pages*page_size_b
		typeset -ri	allocated_pages_size=allocated_pages*page_size_b

		info "Read from $alog"
		info "Page size       : $(fmt_bytesU_2_better -i $page_size_kb)"
		info "Available pages : $available_pages = $(fmt_bytesU_2_better -i $available_pages_size)"
		info "Expected pages  : $expected_pages = $(fmt_bytesU_2_better -i $expected_pages_size)"
		info "Allocated pages : $allocated_pages = $(fmt_bytesU_2_better -i $allocated_pages_size)"
		LN

		if [ $allocated_pages -lt $expected_pages ]
		then
			error "-------------------------"
			error "Not enougth large pages !"
			error "-------------------------"
			LN
		fi
	else
		warning "Fichier alertlog non trouvé :"
		info "$alog"
		LN
	fi
else
	warning "ORACLE_SID undef : '$ORACLE_SID'"
fi

typeset -ri hpage_size_mb=$(to_mb $(get_hugepages_size_kb)K)

typeset -i shm_size_mb=-1
typeset -i shm_used_mb=-1

read fs shm_size_mb shm_used_mb rem<<<"$(df -m /dev/shm | tail -1)"
typeset -ri actual_hpages=$(sysctl -n vm.nr_hugepages)
typeset -ri shm_hpage_mb=$(compute -i "$actual_hpages * $hpage_size_mb")

line_separator
info "Shm size          : $(fmt_number $shm_size_mb)Mb"
info "Shm used          : $(fmt_number $shm_used_mb)Mb"
info "Hpage size        : $(fmt_number $hpage_size_mb)Mb"
info "Hpages configured : $(fmt_number $shm_hpage_mb)Mb ($(fmt_number $actual_hpages) pages)"
LN

typeset -i need_hpages_for_all=$(compute -i "$shm_size_mb / $hpage_size_mb")
info "Max huge pages    : $(fmt_number $need_hpages_for_all)"
LN

