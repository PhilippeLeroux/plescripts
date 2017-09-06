#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-shm_size=bytes	size to allocate for huge pages.
	-db_type=single|rac|single_fs
"

typeset -i	shm_size=-1
typeset		db_type=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db_type=*)
			db_type=${1##*=}
			shift
			;;

		-shm_size=*)
			shm_size=${1##*=}
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

exit_if_param_invalid	db_type "single rac single_fs"	"$str_usage"
exit_if_param_undef		shm_size						"$str_usage"

must_be_user root

typeset	-r	root_tuned=/usr/lib/tuned

#	============================================================================
#	Création et activation du profile Oracle 'normal'
typeset	-r	small_pages_profile=ple-oracle
typeset	-r	oracle_profile_path=$root_tuned/$small_pages_profile
typeset	-r	oracle_profile_conf=$oracle_profile_path/tuned.conf

if [ ! -d $oracle_profile_path ]
then
	exec_cmd "mkdir $oracle_profile_path"
	LN
fi

if [[ $vm_memory_mb_for_rac_db -lt $oracle_memory_prereq || $force_swappiness_to -eq 0 ]]
then # Mieux vaut swapper un max...
	typeset -ri vm_swappiness=90
else # Prérequi Oracle, on a assez de mémoire.
	typeset -ri vm_swappiness=1
fi

cat <<EOS>$oracle_profile_conf
#
# tuned configuration
#

[main]
include=virtual-guest

[sysctl]
#	Redhat advises
#swappiness=0 fait souvent planter l'instance du master.
#Valeur recommandée 1, si la RAM est correcte.
vm.swappiness = $vm_swappiness
vm.dirty_background_ratio = 3
vm.dirty_ratio = 80
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
# Ce paramètre améliore considérablement les perfs (iSCSI)
net.core.message_cost = 0
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

if [ ! -d $hporacle_profile_path ]
then
	exec_cmd "mkdir $hporacle_profile_path"
	LN
fi

#	2 == Taille d'un hpage en Mb
typeset	-ri	total_hp=$(( shm_size / 1024 / 1024 / 2 ))

cat <<EOS>$hporacle_profile_conf
#
# tuned configuration
#

[main]
include=$small_pages_profile

[sysctl]
vm.hugetlb_shm_group=${id_group_dba} # group dba
vm.nr_hugepages=$total_hp
EOS

info "Create tuned profile : $huge_pages_profile"
exec_cmd "cat $hporacle_profile_conf"
LN

line_separator
info "Active le profile $small_pages_profile"
exec_cmd "tuned-adm profile $small_pages_profile"
LN
