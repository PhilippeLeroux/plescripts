#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-local_only]"

typeset	local_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-local_only)
			local_only=yes
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
#	$1 full path alertlog
function read_hpages_from_alert_log
{
	typeset -r alog="$1"

	if [ -f $alog ]
	then
		line_separator
		info "Read from $alog"

		typeset -i	available_pages expected_pages allocated_pages
		read page_size_kb available_pages expected_pages allocated_pages errors <<<$(grep -E "^\s*2048K\s*[0-9].*" $alog | tail -1)

		typeset	-ri	page_size_b=$(to_bytes $page_size_kb)

		typeset -ri	available_pages_size=available_pages*page_size_b
		typeset -ri	expected_pages_size=expected_pages*page_size_b
		typeset -ri	allocated_pages_size=allocated_pages*page_size_b

		info "HugePage size          : $(fmt_bytesU_2_better -i $page_size_kb)"
		info "Available pages        : $available_pages = $(fmt_bytesU_2_better -i $available_pages_size)"
		info "Expected pages         : $expected_pages = $(fmt_bytesU_2_better -i $expected_pages_size)"
		info "Allocated pages        : $allocated_pages = $(fmt_bytesU_2_better -i $allocated_pages_size)"
		LN

		if [ $allocated_pages -lt $expected_pages ]
		then
			warning "----------------------------------------------------"
			warning "Not enougth large pages !"
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
function print_hpages_orcl_instance
{
	if [ -v ORACLE_SID ]
	then
		if [ "${ORACLE_SID:${#ORACLE_SID}-2:1}" == "_" ]
		then # Policy Managed or One Node
			typeset base=$(to_lower ${ORACLE_SID%_*})
		else
			typeset base=$(to_lower "${ORACLE_SID:0:${#ORACLE_SID}-1}")
		fi
		typeset -r alog="$ORACLE_BASE/diag/rdbms/${base}*/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
		read_hpages_from_alert_log $alog
	else
		warning "ORACLE_SID undef"
	fi
}

#	Affiche le nombre de hpages souhaitées par -MGMTDB
function print_hpages_mgmtdb
{
	if ps -ef | grep -q [p]mon_-MGMTDB
	then
		typeset -r alog="$GRID_BASE/diag/rdbms/_mgmtdb/-MGMTDB/trace/alert_-MGMTDB.log"
		info "-MGMTDB HugePages :"
		read_hpages_from_alert_log "$alog"
	else
		info "No -MGMTDB instance."
		LN
	fi
}

typeset	-i	total_memory_used_mb=0

typeset -ri hpage_size_mb=$(to_mb $(get_hugepages_size_kb)K)
typeset -ri	hpage_total=$(get_hugepages_total)
typeset -ri	hpage_free=$(get_hugepages_free)
typeset -ri hpage_used=$(( hpage_total - hpage_free ))

typeset -i shm_max_size_mb=-1
typeset -i shm_used_mb=-1

read fs shm_max_size_mb shm_used_mb rem<<<"$(df -m /dev/shm | tail -1)"

print_hpages_orcl_instance
print_hpages_mgmtdb

typeset -r has_ASM=$(ps -ef|grep "[a]sm_pmon_+ASM" | cut -d_ -f3)
[ x"$has_ASM" != x ] && warning "$has_ASM ignored.\n"

line_separator
info "OS config :"
info "Hpage size             : $(fmt_number $hpage_size_mb)Mb"
info "Hpage total            : $(fmt_number $hpage_total) = $(fmt_number $(( hpage_total * hpage_size_mb )))Mb"
info "Hpage free             : $(fmt_number $hpage_free) = $(fmt_number $(( hpage_free * hpage_size_mb )))Mb"
info "Hpage used             : $(fmt_number $hpage_used) = $(fmt_number $(( hpage_used * hpage_size_mb )))Mb"
LN
typeset -ri total_hpages_used_mb=total_memory_used_mb+hpage_used

line_separator
info "/dev/shm :"
info "Shm max size           : $(fmt_number $shm_max_size_mb)Mb"
info "Shm used               : $(fmt_number $shm_used_mb)Mb"
LN
typeset -ri total_smallpages_used_mb=total_memory_used_mb+shm_used_mb

line_separator
max_memory_mb=$(compute -i "$(memory_total_kb) / 1024")
free_memory_mb=$(compute -i "$(memory_free_kb) / 1024")
info "Max memory             : $(fmt_number $max_memory_mb)Mb"
info "Free memory            : $(fmt_number $free_memory_mb)Mb"
info
info "SGA"
info "  Small pages          : $(fmt_number $total_smallpages_used_mb)Mb (/dev/shm)"
info "  Huge pages           : $(fmt_number $total_hpages_used_mb)Mb"
LN

if [ $local_only != yes ]
then
	if [ $gi_count_nodes -gt 1 ]
	then
		execute_on_other_nodes ". .bash_profile && plescripts/memory/show_pages.sh -local_only"
	elif [ "$(dataguard_config_available)" == yes ]
	then
		typeset -a stby_server_list
		typeset -a physical_list
		load_stby_database
		for server in ${stby_server_list[*]}
		do
			exec_cmd "ssh -t -t $server \". .bash_profile && plescripts/memory/show_pages.sh -local_only\""
		done
	fi
fi
