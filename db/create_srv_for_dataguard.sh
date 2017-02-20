#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	-standby=name
	-standby_host=name

	Must be run from primary server !

	* RAC non pris en compte.
"

script_banner $ME $*

typeset db=undef
typeset pdb=undef
typeset standby=undef
typeset standby_host=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
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
exit_if_param_undef pdb				"$str_usage"
exit_if_param_undef standby			"$str_usage"
exit_if_param_undef standby_host	"$str_usage"

exec_cmd ~/plescripts/db/create_srv_for_single_db.sh	\
							-db=$db						\
							-pdb=$pdb					\
							-role=primary				\
							-start=yes
LN

#	Il faut démarrer les services stby, puis les stopper sinon la création
#	des services échouera sur la stby.
exec_cmd ~/plescripts/db/create_srv_for_single_db.sh	\
							-db=$db						\
							-pdb=$pdb					\
							-role=physical_standby		\
							-start=yes
LN

exec_cmd srvctl stop service -db $db -service $(mk_oci_service $pdb)
LN

exec_cmd srvctl stop service -db $db -service $(mk_java_service $pdb)
LN

exec_cmd "ssh -t $standby_host \". .bash_profile;				\
			~/plescripts/db/create_srv_for_single_db.sh			\
			-db=$standby -pdb=$pdb -role=primary -start=no\""
LN

exec_cmd "ssh -t $standby_host \". .bash_profile;			\
		~/plescripts/db/create_srv_for_single_db.sh			\
		-db=$standby -pdb=$pdb -role=physical_standby -start=yes\""
LN
