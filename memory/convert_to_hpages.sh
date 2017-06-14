#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-emul]"

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
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

ple_enable_log

script_banner $ME $*

must_be_user root

# $1 parameter
# print to stdout parameter value
function read_orcl_parameter
{
	typeset	-r	param=$1

	su - oracle<<EOS | tail -2 | head -1 | tr -s [:space:] | cut -d\  -f4
	sqlplus -s sys/$oracle_password as sysdba
	set heading off
	show parameter $param
EOS
}

# $1 file name
function create_orcl_pfile
{
	su - oracle<<-EOS
	sqlplus -s sys/$oracle_password as sysdba
	create pfile='$1' from spfile;
	EOS
}

# $1 SGA size
# $2 PGA size
function set_orcl_memory_to
{
	typeset	-r	sga=$1
	typeset	-r	pga=$2

	[ $EXEC_CMD_ACTION == NOP ] && return 0 || true

	su - oracle<<-EOS
	sqlplus -s sys/$oracle_password as sysdba
	create pfile='pfile_original.txt' from spfile;
	alter system set sga_max_size=$sga scope=spfile sid='*';
	alter system set sga_target=$sga scope=spfile sid='*';
	alter system set memory_max_target=0 scope=spfile sid='*';
	alter system set memory_target=0 scope=spfile sid='*';
	alter system set pga_aggregate_target=$pga scope=spfile sid='*';
	EOS
}

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

typeset	-r tuned_profile_name=ple-hporacle
typeset -r tuned_profile_file="/usr/lib/tuned/$tuned_profile_name/tuned.conf"

active_tuned_profile=$(tuned-adm active | awk '{ print $4 }')
info "Active tuned profile : $active_tuned_profile"
if [ "$active_tuned_profile" == "$tuned_profile_name" ]
then
	confirm_or_exit "Tuned profile $tuned_profile_name is active, continue"
fi

ORACLE_SID=$(su - oracle -c "echo \$ORACLE_SID")

create_orcl_pfile /tmp/orcl_pfile.txt

orcl_sga_max_size_str=$(grep "__sga_target" /tmp/orcl_pfile.txt | cut -d= -f2)
orcl_sga_max_size_mb=$(to_mb ${orcl_sga_max_size_str}b)

orcl_pga_max_size_str=$(grep "__pga_aggregate_target" /tmp/orcl_pfile.txt | cut -d= -f2)
orcl_pga_max_size_mb=$(to_mb ${orcl_pga_max_size_str}b)

info "$ORACLE_SID : sga = ${orcl_sga_max_size_mb}Mb pga=${orcl_pga_max_size_mb}Mb"
LN

total_hpages=$(count_hugepages_for_sga_of ${orcl_sga_max_size_mb}M)

info "$ORACLE_SID : ${orcl_sga_max_size_mb}Mb"
info "Huge pages : $(fmt_number $total_hpages)"
LN

info "Setup huge pages : $total_hpages + 1"
update_value vm.nr_hugepages "$(( total_hpages + 1 )) # Oracle+ASM" $tuned_profile_file
LN

info "Setup instances for hpage"
set_orcl_memory_to $orcl_sga_max_size_str $orcl_pga_max_size_str
LN

if [ $crs_used == yes ]
then
	info "Stop has"
	exec_cmd "crsctl stop has"
	LN
else
	info "Stop database"

	if [ $EXEC_CMD_ACTION == EXEC ]
	then
		exec_cmd "su - oracle -c \"~/plescripts/db/stop_db.sh\""
	fi
	LN
fi

info "Enable tuned profile ple-oracle"
exec_cmd "tuned-adm profile ple-hporacle"
LN

if [ $crs_used == yes ]
then
	info "Start has"
	exec_cmd "crsctl start has"
	[ $EXEC_CMD_ACTION == EXEC ] && timing 120 "Waiting has" || true
	LN

	exec_cmd "crsctl stat res -t"
	LN
else
	info "Start database"

	if [ $EXEC_CMD_ACTION == EXEC ]
	then
		exec_cmd "su - oracle -c \"~/plescripts/db/start_db.sh -oracle_sid=$ORACLE_SID\""
	fi
	LN
fi

exec_cmd "su - oracle -c \"plescripts/memory/show_pages.sh\""
LN
