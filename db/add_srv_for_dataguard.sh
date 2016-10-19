#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-standby=name
	-standby_host=name
	-pdbName=str

	Must be run from primary server !

	* RAC non pris en compte.
"

script_banner $ME $*

typeset db=undef
typeset standby=undef
typeset standby_host=undef
typeset pdbName=undef

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

		-standby=*)
			standby=${1##*=}
			shift
			;;

		-standby_host=*)
			standby_host=${1##*=}
			shift
			;;

		-pdbName=*)
			pdbName=$(to_upper ${1##*=})
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' unknow."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db				"$str_usage"
exit_if_param_undef standby			"$str_usage"
exit_if_param_undef standby_host	"$str_usage"
exit_if_param_undef pdbName			"$str_usage"

exec_cmd ~/plescripts/db/create_srv_for_single_db.sh	\
			-db=$db -pdbName=$pdbName -role=primary -start=yes
LN

exec_cmd ~/plescripts/db/create_srv_for_single_db.sh	\
			-db=$db -pdbName=$pdbName -role=physical_standby -start=yes
LN

info "Arrêt des services stby (oui ils doivent être démarrés)"
exec_cmd srvctl stop service -db $db -service pdb${pdbName}_stby_oci
LN

exec_cmd srvctl stop service -db $db -service pdb${pdbName}_stby_java
LN

exec_cmd "ssh -t $standby_host \". .bash_profile;				\
				~/plescripts/db/create_srv_for_single_db.sh		\
				-db=$standby -pdbName=$pdbName -role=primary -start=no\""
LN

exec_cmd "ssh -t $standby_host \". .bash_profile;			\
			~/plescripts/db/create_srv_for_single_db.sh		\
			-db=$standby -pdbName=$pdbName -role=physical_standby -start=yes\""
LN
