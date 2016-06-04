#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r OB=${ORACLE_BASE-/u01/app/oracle}

typeset -r str_usage="Usage : $ME -db=<str>
	Si ORACLE_BASE n'est pas définie utilisation de /u01/app/oracle comme répertoire de base."

typeset		db=undef

warning "LE SCRIPT EST OBSOLETE AVEC LINUX 7"
exit 1

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

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

typeset -r sysctl_file=/etc/sysctl.conf
typeset -r alert_pattern="  PAGESIZE  AVAILABLE_PAGES  EXPECTED_PAGES  ALLOCATED_PAGES  ERROR(s)"

db=$(to_lower $db)
typeset -r upper_db=$(to_upper $db)

if [ ! -d $OB/diag/rdbms/$db ]
then
	error "Directory '$OB/diag/rdbms/$db' not exits."
	error "DB $db not exists"
	exit 1
fi

function num_line_hugepages_settings
{
	typeset -r alert_file=$1

	num_line=$(grep -n "$alert_pattern" $alert_file | tail -1 | cut -d: -f1)
	echo $(( $num_line + 4 ))
}

function hugepages_setting
{
	typeset -r instance=$1
	typeset -r alert_file=$2

	typeset -i num_line=$(num_line_hugepages_settings $alert_file)
	typeset -i expected_pages
	read pagesize available_pages expected_pages allocated_pages error<<<$(sed -n "$num_line p" $alert_file)

	# Il me semble qu'il y a toujours 1 page non utilisée, à vérifier à l'usage
	typeset -ri gap_pages=1
	typeset -ri ps=${pagesize:0:${#pagesize}-1}
	typeset -ri sga_size_mb=$(compute "( ($expected_pages-$gap_pages) * $ps ) / 1024")

	info "Read hugepages at line $(fmt_number $num_line) from file :"
	info "  $alert_file"
	LN

	typeset -i nr_hugepages=$(sysctl -n vm.nr_hugepages)
	info "Hugepages :"
	info "    Expected  $(fmt_number $expected_pages)"
	info "    Available $(fmt_number $available_pages)"
	info "    Allocated $(fmt_number $allocated_pages)"
	LN

	info "SGA size = $(fmt_number ${sga_size_mb})Mb"
	LN

	info "OS setting : $(fmt_number $nr_hugepages) hugepages"
	LN
}

exec_cmd "ls -rtl $OB/diag/rdbms/$db/*"
LN

#	TODO à détecter
type=SINGLE

case $type in
	SINGLE)
		line_separator
		FOO=${upper_db:0:8}
		alert_file=$OB/diag/rdbms/$db/$FOO/trace/alert_$FOO.log
		info "Instance : $db"
		if [ ! -f $alert_file ]
		then
			error "Alert file not exists :"
			error "$alert_file"
		else
			hugepages_setting $db $alert_file
		fi
	;;

	RAC)
		find $OB/diag/rdbms/$db/ -type d -name "${upper_db}*" |\
		while read instance_path
		do
			line_separator
			instance=${instance_path##*/}
			alert_file=$instance_path/trace/alert_$instance.log
			info "Instance : $instance"
			if [ ! -f $alert_file ]
			then
				error "Alert file not exists :"
				error "$alert_file"
			else
				hugepages_setting $instance $alert_file
			fi
		done
	;;
esac
