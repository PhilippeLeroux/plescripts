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

typeset -i count_missing_hpages=0

#	Incrémente la variable count_missing_hpages
function read_hpages_from_alert_log
{
	typeset -r alog="$1"

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
			warning "----------------------------------------------------"
			warning "Not enougth large pages !"
			warning "Use : su -c \"./adjust_hpages.sh -nr_hugepages=$expected_pages\""
			warning "----------------------------------------------------"
			LN
			count_missing_hpages=count_missing_hpages+expected_pages
		fi
	else
		warning "Fichier alertlog non trouvé :"
		info "$alog"
		LN
	fi
}

#	Affiche le nombre de hpages souhaitées par l'instance.
function print_hpages_instances
{
	if [ -v ORACLE_SID ]
	then
		if [ "${ORACLE_SID:${#ORACLE_SID}-2:1}" == "_" ]
		then # Policy Managed or One Node
			typeset base=$(to_lower ${ORACLE_SID%_*})
		else
			typeset base=$(to_lower "${ORACLE_SID:0:${#ORACLE_SID}-1}")
		fi
		typeset -r alog="/u01/app/oracle/diag/rdbms/${base}*/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
		read_hpages_from_alert_log $alog
	else
		warning "ORACLE_SID undef : '$ORACLE_SID'"
	fi
}

#	Affiche le nombre de hpages souhaitées par -MGMTDB
function print_hpages_mgmtdb
{
	if ps -ef | grep -q [p]mon_-MGMTDB
	then
		typeset -r alog="$GRID_BASE/diag/rdbms/_mgmtdb/-MGMTDB/trace/alert_-MGMTDB.log"
		read_hpages_from_alert_log "$alog"
	else
		info "Pas d'instance -MGMTDB sur ce nœud."
		LN
	fi
}

typeset -ri hpage_size_mb=$(to_mb $(get_hugepages_size_kb)K)
typeset -ri	hpage_total=$(get_hugepages_total)
typeset -ri	hpage_free=$(get_hugepages_free)
typeset -ri hpage_used=$(( hpage_total - hpage_free ))

typeset -i shm_size_mb=-1
typeset -i shm_used_mb=-1

read fs shm_size_mb shm_used_mb rem<<<"$(df -m /dev/shm | tail -1)"
typeset -ri actual_hpages=$(sysctl -n vm.nr_hugepages)
typeset -ri shm_hpage_mb=$(compute -i "$actual_hpages * $hpage_size_mb")
typeset -i need_hpages_for_all=$(compute -i "$shm_size_mb / $hpage_size_mb")

print_hpages_instances
print_hpages_mgmtdb

if [ $count_missing_hpages -ne 0 ]
then
	line_separator
	warning "Set large pages :"
	warning "Use : su -c \"./adjust_hpages.sh -nr_hugepages=$count_missing_hpages\""
	LN
fi

line_separator
info "Shm size          : $(fmt_number $shm_size_mb)Mb (max : $need_hpages_for_all Hpages)"
info "Shm used          : $(fmt_number $shm_used_mb)Mb"
LN

info "Hpage size        : $(fmt_number $hpage_size_mb)Mb"
info "Hpage total       : $(fmt_number $hpage_total) = $(fmt_number $(( hpage_total * hpage_size_mb )))Mb"
info "Hpage free        : $(fmt_number $hpage_free) = $(fmt_number $(( hpage_free * hpage_size_mb )))Mb"
info "Hpage used        : $(fmt_number $hpage_used) = $(fmt_number $(( hpage_used * hpage_size_mb )))Mb"
LN

info "Hpages configured : $(fmt_number $shm_hpage_mb)Mb ($(fmt_number $actual_hpages) pages)"
LN
