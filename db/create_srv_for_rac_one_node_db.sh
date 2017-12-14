#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
"

typeset db=undef
typeset pdb=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

typeset -r oci_service=$(mk_oci_service $pdb)
typeset -r java_service=$(mk_java_service $pdb)

info "Create services for RAC One Node."
exec_cmd srvctl add service -db $db -service $oci_service -pdb $pdb
exec_cmd srvctl start service -db $db -service $oci_service
exec_cmd "~/plescripts/db/add_tns_alias.sh -service=$oci_service	\
										-host_name=$(hostname -s)"

exec_cmd srvctl add service -db $db -service $java_service -pdb $pdb
exec_cmd srvctl start service -db $db -service $java_service
LN

