#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-reset]
Par défaut active les hpages, pour revenir aux pages normalles utiliser -reset"

script_banner $ME $*

#	activate_profile
typeset action=normal

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-action=*)
			action=${1##*=}
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

exit_if_param_invalid action "normal activate_profile" "$str_usage"

if [ $USER != root ]
then
	error "USER must be root !"
	exit 1
fi

if [ ! -d /usr/lib/tuned/ple-hporacle ]
then
	error "Tuned profile ple-hporacle not exist !"
	exit 1
fi

function setup_oracle_db
{
	line_separator
	info "Setup Oracle instance"
	exec_cmd "su - oracle -c '~/plescripts/memory/orcl_setup_hp.sh'"
	LN
}

function setup_asm
{
	line_separator
	info "Setup Grid instance"
	exec_cmd "su - grid -c '~/plescripts/memory/grid_setup_hp.sh'"
	LN
}

function stop_has
{
	line_separator
	info "Stop has"
	exec_cmd "crsctl stop has"
	LN
}

function start_has
{
	line_separator
	info "Start has"
	exec_cmd "crsctl start has"
	LN
}

function stop_cluster
{
	line_separator
	info "Stop Cluster"
	exec_cmd "crsctl stop cluster -all"
	LN
}

function start_cluster
{
	line_separator
	info "Stop Cluster"
	exec_cmd "crsctl start cluster -all"
	LN
}

function activate_hporacle_profile
{
	line_separator
	info "Activate tuned profile ple-hporacle (Huge Pages)"
	LN

	exec_cmd "grep ^Huge /proc/meminfo"
	LN

	#	Sinon les hpages ne sont pas allouées.
	exec_cmd "mount -o remount,size=0 /dev/shm"
	LN

	timing 5

	exec_cmd "tuned-adm profile ple-hporacle"
	LN

	timing 10
	exec_cmd "grep ^Huge /proc/meminfo"
	LN
}

case $action in
	activate_profile)
		#	Le cluster est stoppé ici.
		activate_hporacle_profile
		exit 0
		;;
esac

setup_oracle_db

setup_asm

[ x"$gi_node_list" == x ] && stop_has || stop_cluster

activate_hporacle_profile

if [ x"$gi_node_list" != x ]
then
	execute_on_other_nodes "~/plescripts/memory/${ME##*/} -action=activate_profile"
	LN
fi

confirm_or_exit "Démarrer :"
[ x"$gi_node_list" == x ] && start_has || start_cluster
