#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-emul]
	Mise à jour de l'OS, tient compte des bases.
"

script_banner $ME $*

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

#	Lors d'une mise à jour la configuration d'oracleasm a été perdu.
#	Donc elle est refaite par précaution.
function update_oracle_asm_configuration
{
	line_separator
	info "Configure oracleasm :"
	exec_cmd "~/plescripts/oracle_preinstall/configure_oracleasm.sh"
	LN
}

test_if_cmd_exists olsnodes
if [ $? -ne 0 ]
then
	error "Work only with Grid Infra..."
	exit 1
fi

test_if_rpm_update_available
if [ $? -ne 0 ]
then
	info "No update."
	exit 0
fi

if [ $gi_count_nodes -eq 1 ]
then
	info "Update : $gi_current_node"
	LN

	line_separator
	info "Stop Grid Infra :"
	exec_cmd "crsctl stop has"
	LN

	line_separator
	info "update :"
	exec_cmd "yum -y update"
	LN

	update_oracle_asm_configuration

	line_separator
	info "Reboot"
	exec_cmd -c systemctl reboot
	LN
else
	info "Update : $gi_current_node $gi_node_list"
	LN

	line_separator
	info "Stop instances :"
	while IFS='.' read prefix dbname suffix
	do
		exec_cmd -c srvctl stop instance -db $dbname -node $gi_current_node
	done<<<"$(crsctl stat res -t | grep -E '^ora\..*\.db')"
	LN

	line_separator
	info "Stop crs on node $gi_current_node :"
	exec_cmd "crsctl stop crs"
	LN

	line_separator
	exec_cmd "yum -y update"
	LN

	update_oracle_asm_configuration

	line_separator
	info "Si des FS du type OCFS2 sont utilisés, mettre à jour la configuration."
	LN
	info "Mettre à jour les noeuds $gi_node_list"
	LN

	line_separator
	info "Reboot"
	exec_cmd -c systemctl reboot
	LN
fi
