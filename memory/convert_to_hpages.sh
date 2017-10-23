#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=NOP

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME [-doit]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-doit)
			EXEC_CMD_ACTION=EXEC
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

[ $EXEC_CMD_ACTION == EXEC ] && ple_enable_log -params $PARAMS || true

must_be_user root

# $1 file name
function create_orcl_pfile
{
	info "Create pfile $1"
	LN

	su - oracle<<-EOS
	sqlplus -s sys/$oracle_password as sysdba
	create pfile='$1' from spfile;
	EOS
	LN
}

function read_sga_pga_value
{
	# Quand memory_target est spécifié il faut lire le pfile,
	# s'il n'y a que memory_max_target il faut lire les
	# paramètre en base.
	# (note je ne me souviens plus vraiment pourquoi je suis
	# passé par le pfile pour lire les paramètres...
	orcl_sga_max_size_str=$(grep "__sga_target" $pfile | tail -1 | cut -d= -f2)
	if [ x"$orcl_sga_max_size_str" == x ]
	then
		while read param value
		do
			case "$param" in
				pga_aggregate_target)
					orcl_pga_max_size_str=$(to_bytes $value)
					;;

				sga_max_size)
					orcl_sga_max_size_str=$(to_bytes $value)
					;;

				*)
					error "param = '$param' unknow..."
					LN
					exit 1
			esac
		done<<<"$(su - oracle -c "~/plescripts/tmp/read_sga_pga.sh")"

		if [ x"$orcl_sga_max_size_str" == x ]
		then
			error "Cannot read parameter __sga_target"
			LN
			exit 1
		fi
	fi
	orcl_sga_max_size_mb=$(to_mb "${orcl_sga_max_size_str}b")

	if [ x"$orcl_pga_max_size_str" == x ]
	then
		orcl_pga_max_size_str=$(grep "__pga_aggregate_target" $pfile | tail -1 | cut -d= -f2)
	fi
	if [ x"$orcl_pga_max_size_str" == x ]
	then
		error "Cannot read parameter __pga_aggregate_target"
		LN
		exit 1
	fi
	orcl_pga_max_size_mb=$(to_mb "${orcl_pga_max_size_str}b")

	info "$ORACLE_SID : sga = ${orcl_sga_max_size_mb}Mb pga=${orcl_pga_max_size_mb}Mb"
	LN
}

# $1 SGA size
# $2 PGA size
function set_orcl_memory_to
{
	typeset	-r	sga=$1
	typeset	-r	pga=$2

	info "Setup sga to $sga and pga to $pga"
	LN

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
LN

ORACLE_SID=$(su - oracle -c "echo \$ORACLE_SID")

typeset -r pfile=/tmp/orcl_pfile.txt
create_orcl_pfile $pfile

read_sga_pga_value

total_hpages=$(count_hugepages_for_sga_of "${orcl_sga_max_size_mb}M")
info "Huge pages for $ORACLE_SID : $(fmt_number $total_hpages)"
LN

info "Setup huge pages : $total_hpages + 1"
update_value vm.nr_hugepages "$(( total_hpages + 1 )) # Oracle+ASM" $tuned_profile_file
LN

set_orcl_memory_to $orcl_sga_max_size_str $orcl_pga_max_size_str

if [ $crs_used == yes ]
then
	if [ $gi_count_nodes -eq 1 ]
	then
		info "Stop has"
		exec_cmd "crsctl stop has"
		LN
	else
		info "Copy profile to all nodes."
		for node in $gi_node_list
		do
			exec_cmd "scp $tuned_profile_file ${node}:$tuned_profile_file"
			LN
		done

		info "Stop cluster"
		exec_cmd "crsctl stop cluster -all"
		LN
	fi
else
	info "Stop database"

	exec_cmd "su - oracle -c \"~/plescripts/db/stop_db.sh\""
	LN
fi

info "Enable tuned profile ple-oracle"
exec_cmd "tuned-adm profile ple-hporacle"
LN
if [[ $crs_used == yes && $gi_count_nodes -gt 1 ]]
then
	execute_on_other_nodes "tuned-adm profile ple-hporacle"
	LN
fi

if [ $crs_used == yes ]
then
	if [ $gi_count_nodes -eq 1 ]
	then
		info "Start has"
		exec_cmd "crsctl start has"
		[ $EXEC_CMD_ACTION == EXEC ] && timing 120 "Waiting has" || true
		LN
	else
		info "Start cluster"
		exec_cmd "crsctl start cluster -all"
		[ $EXEC_CMD_ACTION == EXEC ] && timing 120 "Waiting cluster" || true
		LN
	fi

	exec_cmd "crsctl stat res -t"
	LN
else
	info "Start database"

	exec_cmd "su - oracle -c \"~/plescripts/db/start_db.sh -oracle_sid=$ORACLE_SID\""
	LN
fi

exec_cmd -f "su - oracle -c \"plescripts/memory/show_pages.sh\""
LN

if [ "$EXEC_CMD_ACTION" == NOP ]
then
	info "To apply :"
	info "./${ME##*/} -doit"
	LN
fi
