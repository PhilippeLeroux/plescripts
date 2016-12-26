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
\t-service_name=name
\t[-drop_wallet=yes]\tyes|no
"

script_banner $ME $*

typeset	service_name=undef
typeset drop_wallet=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-service_name=*)
			service_name=${1##*=}
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

exit_if_param_undef service_name	"$str_usage"
exit_if_param_invalid drop_wallet "yes no" "$str_usage"

must_be_user root

typeset -r pdb_name=$(sed 's/pdb\(.*\)_oci/\1/' <<<"$service_name")
typeset	-r db_name=$(to_lower $(extract_db_name_from $pdb_name))

exec_cmd -c  "sudo -iu grid crsctl delete res pdb.${pdb_name}.dbfs -f"
LN

line_separator
exec_cmd -c "sudo -iu oracle plescripts/db/dbfs/oracle_drop_all.sh	\
							-pdb_name=$pdb_name -drop_wallet=$drop_wallet"
LN

line_separator
execute_on_all_nodes "rm -f /etc/ld.so.conf.d/usr_local_lib.conf"
LN

line_separator
typeset	-r	rel=$(cut -d. -f1-2<<<"$oracle_release")
typeset	-r	ver=$(cut -d. -f1<<<"$oracle_release")
[ -h libclntsh.so.$rel ] && \
		execute_on_all_nodes rm -f $ORACLE_HOME/lib/libclntsh.so.$rel || true
[ -h libnnz$ver.so ] &&	\
		execute_on_all_nodes rm -f $ORACLE_HOME/lib/libnnz$ver.so || true
[ -h libclntshcore.so.$rel ] &&	\
		execute_on_all_nodes rm -f $ORACLE_HOME/lib/libclntshcore.so.$rel || true
[ -h libfuse.so ] &&	\
		execute_on_all_nodes rm -f libfuse.so || true
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
