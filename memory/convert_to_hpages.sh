#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

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

must_be_user root

function read_orcl_parameter
{
	typeset	-r	param=$1

	su - oracle<<EOS | tail -2 | head -1 | tr -s [:space:] | cut -d\  -f4
	sqlplus -s sys/$oracle_password as sysdba
	set heading off
	show parameter $param
EOS
}

function read_asm_parameter
{
	typeset	-r	param=$1

	su - grid<<EOS | tail -2 | head -1 | tr -s [:space:] | cut -d\  -f4
	sqlplus -s sys/$oracle_password as sysdba
	set heading off
	show parameter $param
EOS
}

function set_orcl_sga_to
{
	typeset	-r	sga=$1

	su - oracle<<EOS
	sqlplus -s sys/$oracle_password as sysdba
	create pfile='pfile_original.txt' from spfile;
	alter system set sga_max_size=$sga scope=spfile sid='*';
	alter system set sga_target=$sga scope=spfile sid='*';
	alter system set memory_max_target=0 scope=spfile sid='*';
	alter system set memory_target=0 scope=spfile sid='*';
EOS
}

function set_asm_sga_to
{
	typeset	-r	sga=$1

	su - grid<<EOS
	sqlplus -s sys/$oracle_password as sysdba
	create pfile='pfile_original.txt' from spfile;
	alter system set sga_max_size=$sga scope=spfile sid='*';
	alter system set sga_target=$sga scope=spfile sid='*';
	alter system set memory_max_target=0 scope=spfile sid='*';
EOS
}

typeset	-r tuned_profile_name=ple-hporacle
typeset -r tuned_profile_file="/usr/lib/tuned/$tuned_profile_name/tuned.conf"

active_tuned_profile=$(tuned-adm active | awk '{ print $4 }')
info "Active tuned profile : $active_tuned_profile"
if [ "$active_tuned_profile" == "$tuned_profile_name" ]
then
	confirm_or_exit "Tuned profile $tuned_profile_name is active, continue"
fi

orcl_sga_max_size_str=$(read_orcl_parameter sga_max_size)
asm_sga_max_size_str=$(read_asm_parameter sga_max_size)

orcl_sga_max_size_mb=$(to_mb $orcl_sga_max_size_str)
asm_sga_max_size_mb=$(to_mb $asm_sga_max_size_str)

sga_total_mb=$(( orcl_sga_max_size_mb + asm_sga_max_size_mb ))

total_hpages=$(count_hugepages_for_sga_of ${sga_total_mb}M)

info "Oracle      : $orcl_sga_max_size_str"
info "ASM         : $asm_sga_max_size_str"
info "Total SGA   : $(fmt_number $sga_total_mb)M"
info "Huge pages  : $(fmt_number $total_hpages)"
LN

info "Setup huge pages : $total_hpages + 1"
update_value vm.nr_hugepages "$(( total_hpages + 1 )) # Oracle+ASM" $tuned_profile_file
LN

info "Setup instances for hpage"
set_orcl_sga_to $orcl_sga_max_size_str
set_asm_sga_to $asm_sga_max_size_str
LN

info "Stop has"
exec_cmd "crsctl stop has"
LN

info "Enable tuned profile hple-oracle"
exec_cmd "tuned-adm profile ple-hporacle"
LN

info "Disable /dev/shm"
exec_cmd "sed -i \"/\/dev\/shm/d\" /etc/fstab"
exec_cmd "echo \"tmpfs   /dev/shm    tmpfs   defaults,size=0 0 0\" >> /etc/fstab"
exec_cmd "mount -o remount /dev/shm"
LN

info "Start has"
exec_cmd "crsctl start has"
timing 120 "Waiting has"
LN

exec_cmd "crsctl stat res -t"
LN
