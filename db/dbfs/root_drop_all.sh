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
"Usage :
$ME
\t-db=name
\t-pdb=name
\t-service=name
\t-physical\t\tif physical standby database.
\t[-drop_wallet=yes]\tyes|no
"

script_banner $ME $*

typeset	db=undef
typeset	pdb=undef
typeset	service=undef
typeset	role=primary
typeset drop_wallet=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-service=*)
			service=${1##*=}
			shift
			;;

		-physical)
			role=physical
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

exit_if_param_undef db		"$str_usage"
exit_if_param_undef pdb		"$str_usage"
exit_if_param_undef service	"$str_usage"

exit_if_param_invalid drop_wallet "yes no" "$str_usage"

must_be_user root

exit_if_service_not_exists $db $service

line_separator
exec_cmd -c  "sudo -iu grid crsctl stop res pdb.${pdb}.dbfs -f"
LN
exec_cmd -c  "sudo -iu grid crsctl delete res pdb.${pdb}.dbfs -f"
LN

if [ $role == primary ]
then
	line_separator
	exec_cmd -c "sudo -iu oracle plescripts/db/dbfs/oracle_drop_all.sh	\
							-pdb=$pdb -drop_wallet=$drop_wallet"
	LN
fi

line_separator
execute_on_all_nodes "rm -rf /mnt/$pdb"
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
execute_on_all_nodes "sed -i '/@$service/d' /etc/fstab"
LN

line_separator
execute_on_all_nodes yum -y remove fuse fuse-libs
LN
