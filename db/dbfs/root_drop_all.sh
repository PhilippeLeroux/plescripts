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
\t-service=auto     auto or service name
\t-physical         for physical standby database.
\t[-drop_wallet]    drop wallet store
\t[-uninstall_fuse] uninstall fuse
"

script_banner $ME $*

typeset	db=undef
typeset	pdb=undef
typeset	service=auto
typeset	role=primary
typeset drop_wallet=no
typeset uninstall_fuse=no

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

		-drop_wallet)
			drop_wallet=yes
			shift
			;;

		-uninstall_fuse)
			uninstall_fuse=yes
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

must_be_user root

[ $service == auto ] && service=$(to_lower $(mk_oci_service $pdb)) || true

exit_if_service_not_exists $db $service

if [ $role == primary ]
then
	line_separator
	exec_cmd -c "sudo -iu oracle plescripts/db/dbfs/drop_dbfs.sh	\
						-db=$db -pdb=$pdb -drop_wallet=$drop_wallet"
	LN
fi

line_separator
execute_on_all_nodes "rm -rf /mnt/$pdb"
LN

if [ $uninstall_fuse == yes ]
then
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
fi

line_separator
execute_on_all_nodes "sed -i '/@$service/d' /etc/fstab"
LN

if [ $uninstall_fuse == yes ]
then
	line_separator
	execute_on_all_nodes yum -y remove fuse fuse-libs
	LN
fi
