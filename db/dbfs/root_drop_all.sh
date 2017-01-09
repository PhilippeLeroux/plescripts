#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
\t-pdb_name=name
\t[-drop_wallet=yes]\tyes|no
"

script_banner $ME $*

typeset	pdb_name=undef
typeset drop_wallet=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb_name=*)
			pdb_name=${1##*=}
			shift
			;;

		-drop_wallet=*)
			drop_wallet=${1##*=}
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

exit_if_param_undef pdb_name	"$str_usage"
exit_if_param_invalid drop_wallet "yes no" "$str_usage"

must_be_user root

typeset	-r service_name=$(make_oci_service_name_for $pdb_name)
typeset	-r db_name=$(to_lower $(extract_db_name_from $pdb_name))

exit_if_service_not_running $db_name $pdb_name $service_name

line_separator
exec_cmd -c  "sudo -iu grid crsctl stop res pdb.${pdb_name}.dbfs -f"
LN
exec_cmd -c  "sudo -iu grid crsctl delete res pdb.${pdb_name}.dbfs -f"
LN

line_separator
exec_cmd -c "sudo -iu oracle plescripts/db/dbfs/oracle_drop_all.sh	\
							-pdb_name=$pdb_name -drop_wallet=$drop_wallet"
LN

line_separator
execute_on_all_nodes "rm -rf /mnt/$pdb_name"
LN

line_separator
execute_on_all_nodes "rm -f /etc/ld.so.conf.d/usr_local_lib.conf"
LN

line_separator
typeset	-r	rel=$(cut -d. -f1-2<<<"$oracle_release")
typeset	-r	ver=$(cut -d. -f1<<<"$oracle_release")
execute_on_all_nodes rm -f /usr/local/lib/libclntsh.so.$rel
execute_on_all_nodes rm -f /usr/local/lib/libnnz$ver.so
execute_on_all_nodes rm -f /usr/local/lib/libclntshcore.so.$rel
execute_on_all_nodes rm -f /usr/local/lib/libfuse.so
execute_on_all_nodes ldconfig
LN

line_separator
execute_on_all_nodes "rm -f /sbin/mount.dbfs"
LN

line_separator
execute_on_all_nodes "sed -i '/@$service_name/d' /etc/fstab"
LN

line_separator
execute_on_all_nodes yum -y remove fuse fuse-libs
LN
