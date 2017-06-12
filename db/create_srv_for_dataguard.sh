#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

#	****************************************************************************
#	Le scripts db/stby/create_dataguard.sh la fonction create_dataguard_services
#	utilise une autre méthode pour crééer les services.
#	****************************************************************************

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

if test_if_cmd_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

# [-c]
# $@ command
#
# Utilise la variable standby_host
function ssh_stby
{
	if [ "$1" == "-c" ]
	then
		typeset farg="-c"
		shift
	else
		typeset farg
	fi

	exec_cmd $farg "ssh -t ${standby_host} '. .bash_profile; $@'"
}

#	Les services 'stby' sont démarrées, il seront stoppées par les fonctions
#	create_standby_services[_no_crs]
function create_or_update_primary_services
{
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
}

function create_standby_services
{
	line_separator
	info "$db[$pdb] : stop all standby services."
	LN

	#	Arrêt des services stdby.
	exec_cmd srvctl stop service -db $db -service $(mk_oci_stby_service $pdb)
	LN

	exec_cmd srvctl stop service -db $db -service $(mk_java_stby_service $pdb)
	LN

	line_separator
	info "Create service on standby $standby_host"
	LN

	ssh_stby "~/plescripts/db/create_srv_for_single_db.sh	\
				-db=$standby -pdb=$pdb -role=primary -start=no"
	LN

	ssh_stby "~/plescripts/db/create_srv_for_single_db.sh	\
			-db=$standby -pdb=$pdb -role=physical_standby -start=yes"
	LN
}

function create_standby_services_no_crs
{
	# $1 pdb name
	# $2 service name
	function stop_stby_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.stop_service( '$2' );"
	}

	# $1 pdb name
	function open_stby_pdb
	{
		set_sql_cmd "alter pluggable database $1 open read only;"
	}

	line_separator
	info "$db[$pdb] : stop all standby services."
	LN

	typeset -r oci_stby_service=$(mk_oci_stby_service $pdb)
	sqlplus_cmd "$(stop_stby_service $pdb $oci_stby_service)"
	LN

	typeset -r java_stby_service=$(mk_java_stby_service $pdb)
	sqlplus_cmd "$(stop_stby_service $pdb $java_stby_service)"
	LN

	line_separator
	info "Open pluggable database $pdb on standby $standby"
	sqlplus_cmd_with "sys/$oracle_password@$standby as sysdba"	\
													"$(open_stby_pdb $pdb)"
	LN
}

create_or_update_primary_services

if [ $crs_used == yes ]
then
	create_standby_services
else
	create_standby_services_no_crs
fi

line_separator
exec_cmd "~/plescripts/db/update_tns_alias_for_dataguard.sh	\
								-pdb=$pdb -dataguard_list=$standby_host"

