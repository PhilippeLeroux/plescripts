#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-service_name=name
"

script_banner $ME $*

typeset	service_name=undef

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

must_be_user root

typeset -r pdb_name=$(sed 's/pdn\(.*\)_oci/\1/' <<<"$service_name")
typeset	-r db_name=$(to_lower $(extract_db_name_from $pdb_name))

exec_cmd -c  "sudo -iu grid crsctl delete res pdb.${pdb_name}.dbfs -f"
LN

line_separator
exec_cmd -c "sudo -iu oracle plescripts/db/dbfs/drop_all.sh -pdb_name=$pdb_name"
LN

line_separator
exec_cmd rm -f /etc/ld.so.conf.d/usr_local_lib.conf
LN

line_separator
typeset	-r	rel=$(cut -d. -f1-2<<<"$oracle_release")
typeset	-r	ver=$(cut -d. -f1<<<"$oracle_release")
[ -h libclntsh.so.$rel ] && \
			exec_cmd rm -f $ORACLE_HOME/lib/libclntsh.so.$rel || true
[ -h libnnz$ver.so ] &&	\
			exec_cmd rm -f $ORACLE_HOME/lib/libnnz$ver.so || true
[ -h libclntshcore.so.$rel ] &&	\
			exec_cmd rm -f $ORACLE_HOME/lib/libclntshcore.so.$rel || true
[ -h libfuse.so ] &&	\
			exec_cmd rm -f libfuse.so || true
exec_cmd ldconfig
LN

line_separator
exec_cmd "rm -f /sbin/mount.dbfs"
LN

line_separator
exec_cmd "sed -i '/#.*@$service_name/d' /etc/fstab"
LN

line_separator
exec_cmd yum -y remove fuse fuse-libs
LN
