#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

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

typeset	-r	root_tuned=/usr/lib/tuned

#	============================================================================
#	Création et activation du profile Oracle 'normal'
typeset	-r	small_pages_profile=ple-oracle
typeset	-r	oracle_profile_path=$root_tuned/$small_pages_profile
typeset	-r	oracle_profile_conf=$oracle_profile_path/tuned.conf

[ ! -d $oracle_profile_path ] && exec_cmd "mkdir $oracle_profile_path" && LN

cat <<EOS>$oracle_profile_conf
#
# tuned configuration
#

[main]
include=virtual-guest

[sysctl]
#	Redhat advises
#swappiness=0 fait souvent planter l'instance du master.
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 80
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
EOS

info "Create tuned profile : $small_pages_profile"
exec_cmd "cat $oracle_profile_conf"
LN

#	============================================================================
#	Création et activation du profile Oracle permettant l'utilisation des hpages
typeset -ri id_group_dba=$(grep "^dba" /etc/group | cut -d':' -f3)
typeset	-r	huge_pages_profile=ple-hporacle
typeset	-r	hporacle_profile_path=$root_tuned/$huge_pages_profile
typeset	-r	hporacle_profile_conf=$hporacle_profile_path/tuned.conf

[ ! -d $hporacle_profile_path ] && exec_cmd "mkdir $hporacle_profile_path" && LN

if [[ "$hack_asm_memory" == "0" || "$shm_for_db" == "0" ]]
then
	typeset	-ri	total_hp=0
else
	#	2 == Taille d'un hpage en Mb
	typeset	-ri	total_hp=$(( $(to_mb $hack_asm_memory) + $(to_mb $shm_for_db) / 2 ))
fi

cat <<EOS>$hporacle_profile_conf
#
# tuned configuration
#

[main]
include=$small_pages_profile

[sysctl]
vm.hugetlb_shm_group=${id_group_dba} # group dba
vm.nr_hugepages=$total_hp # asm + databases
EOS

info "Create tuned profile : $huge_pages_profile"
exec_cmd "cat $hporacle_profile_conf"
LN

#	============================================================================

line_separator
info "Active le profile $small_pages_profile"
exec_cmd "tuned-adm profile $small_pages_profile"
LN
