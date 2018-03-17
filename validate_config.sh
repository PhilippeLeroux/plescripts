#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset		test_iso_ol7=yes
typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage : $ME [-skip_test_iso_ol7]
Ce script vérifie que le virtual-host remplie les conditions nécessaires au bon
fonctionnement de la démo."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-skip_test_iso_ol7)
			test_iso_ol7=no
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

typeset -i count_errors=0

function scripts_exists
{
	line_separator
	info -n "Directory exists \$HOME/plescripts "
	if [ ! -d "$HOME/plescripts" ]
	then
		info -f "[$KO]"
		error "	must contains all scripts."
		((++count_errors))
	else
		info -f "[$OK]"
	fi
	LN
}

function runInstaller_exists
{
	line_separator
	info "Oracle $orarel extracted :"
	info -n "Exist \$HOME/$oracle_install/database/runInstaller "
	if [ ! -f "$HOME/$oracle_install/database/runInstaller" ]
	then
		info -f "[$KO]"
		error " \$HOME/$oracle_install/database must contains Oracle installer."
		LN
		((++count_errors))
	else
		info -f "[$OK]"
		LN
	fi

	if [ "$orarel" == "12.2" ]
	then
		info "Grid zip $orarel :"
		info -n "Exist \$HOME/$oracle_install/grid/linuxx64_12201_grid_home.zip "
		if [ ! -f "$HOME/$oracle_install/grid/linuxx64_12201_grid_home.zip" ]
		then
			info -f "[$KO]"
			error " \$HOME/$oracle_install/grid must contains linuxx64_12201_grid_home.zip."
			LN
			((++count_errors))
		else
			info -f "[$OK]"
			LN
		fi
	elif [ "$orarel" == "12.1" ]
	then
		info "Grid $orarel extracted :"
		info -n "Exist \$HOME/$oracle_install/grid/runInstaller "
		if [ ! -f "$HOME/$oracle_install/grid/runInstaller" ]
		then
			info -f "[$KO]"
			error " \$HOME/$oracle_install/grid must contains Grid installer."
			LN
			((++count_errors))
		else
			info -f "[$OK]"
			LN
		fi
	else
		error "Release '$orarel' invalid."
		exit 1
	fi
}

function _is_exported
{
	typeset -r	directory=$1

	info -n "  - $(replace_paths_by_shell_vars $directory) "
	typeset	-r	network=$(right_pad_ip $infra_network)
	if grep -qE "${directory}\s*${network}.*" /etc/exports 2>/dev/null
	then
		info -f "[$OK]"
		return 0
	else
		((++count_errors))
		info -f "[$KO]"
		return 1
	fi
}

function validate_NFS_exports
{
	line_separator
	typeset	-r	network=$(right_pad_ip $infra_network)
	info "Validate NFS exports from $client_hostname on network ${network} :"
	if ! _is_exported $HOME/plescripts
	then
		info "    add to /etc/exports : $HOME/plescripts $network/$if_pub_prefix(rw,sync,subtree_check,no_root_squash)"
	fi
	if ! _is_exported $HOME/$oracle_install
	then
		info "    add to /etc/exports : $HOME/oracle_install/$orarel $network/$if_pub_prefix(ro,subtree_check)"
	fi
	LN
}

function ISO_OLinux7_exists
{
	line_separator
	info -n "ISO Oracle Linux $OL7_LABEL exists $(replace_paths_by_shell_vars $full_linux_iso_name) "
	if [ ! -f "$full_linux_iso_name" ]
	then
		info -f "[$KO]"
		((++count_errors))
	else
		info -f "[$OK]"
	fi
	LN
}

function validate_gateway
{
	line_separator
	info -n "Validate gateway $gateway "

	if ping -c 1 $gateway >/dev/null 2>&1
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
	fi
	LN
}

function validate_master_time_server
{
	[ "$master_time_server" == internet ] && return || true

	line_separator
	info -n "Time synchronization server : ping of $master_time_server "

	if ping -c 1 $master_time_server >/dev/null 2>&1
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
	fi
	LN
}

function validate_nic
{
	line_separator
	info -n "Validate NIC $if_net_bridgeadapter "

	if [ "$if_net_bridgeadapter" == "undef" ]
	then
		info -f "[$KO]"
		((++count_errors))
	else
		info -f "[$OK]"
	fi
	LN
}

function validate_resolv_conf
{
	line_separator
	info "Validate resolv.conf "

	info -n " - Test : search $infra_domain "
	if grep search /etc/resolv.conf | grep -q $infra_domain
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
	fi

	info -n " - Test : nameserver $infra_ip "
	if grep -q ${infra_ip} /etc/resolv.conf
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
	fi
	LN
}

function _shell_in_path
{
	line_separator
	info -n "\$PATH contains \$HOME/plescripts/shell "
	if command_exists stop_vm
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
	fi
	LN
}

function _in_path
{
	typeset		option=no
	if [ "$1" == "-o" ]
	then
		option=yes
		shift
	fi
	typeset -r	cmd=$1
	typeset -r	cmd_msg=$2

	typeset -r msg=$(printf "%-10s " $cmd)
	info -n "  $msg"
	if command_exists $cmd
	then
		info -f "[$OK]"
	else
		if [ $option == yes ]
		then
			info -f -n "[${BLUE}optional${NORM}]"
		else
			((++count_errors))
			info -f -n "[$KO]"
		fi
		info -f " $cmd_msg"

		typeset -r	distrib=$(grep ^NAME /etc/os-release | cut -d= -f2)

		if [[ $option == no && $distrib =~ openSUSE ]]
		then
			exec_cmd -ci cnf $cmd
			LN
		fi
	fi
}

function test_tools
{
	_shell_in_path

	info "Installed :"
	_in_path VBoxManage	"Install VirtualVox"
	_in_path nc			"Install nc"
	_in_path ssh		"Install ssh"
	_in_path -o git		"Install git"
	_in_path -o tmux	"Install tmux"
	LN
	if command_exists VBoxManage
	then
		info -n "$USER in group vboxusers "
		gid_vboxusers=$(cat /etc/group|grep vboxusers|cut -d: -f3)
		if  id|grep -q $gid_vboxusers
		then
			info -f "[$OK]"
			LN
		else
			((++count_errors))
			if cat /etc/group|grep -qE "^vboxusers.*$USER*"
			then
				info -f "[$KO] : disconnect user $USER and connect again."
				LN
			else
				info -f "[$KO] execute : sudo usermod -a -G vboxusers $USER"
				warning "Take effect on a new connection."
				LN
			fi
		fi
	fi
}

function test_if_configure_global_cfg_executed
{
	line_separator
	info -n "~/plescripts/configure_global.cfg.sh executed "
	typeset	errors_msg
	typeset -i exec_global=0

	typeset	hn=$(hostname -s)
	if [ "$hn" != "$client_hostname" ]
	then
		((++count_errors))
		exec_global=1
		errors_msg="\n\tclient_hostname=$client_hostname expected $hn"
	fi

	if [ "$USER" != "$common_user_name" ]
	then
		((++count_errors))
		exec_global=1
		errors_msg="$errors_msg\n\tcommon_user_name=$common_user_name expected $USER"
	fi

	if [ x"$vm_path" == x ]
	then
		((++count_errors))
		exec_global=1
		errors_msg="$errors_msg\n\tvm_path not set."
	fi

	if [ $exec_global -eq 1 ]
	then
		info -f "[$KO]"
		info "Execute : ./configure_global.cfg.sh"
		error "Errors :$errors_msg"
		info "vm_path = $vm_path"
	else
		info -f "[$OK]"
	fi
	LN
}

function test_timer_hpet
{
	if [ ! -f /sys/devices/system/clocksource/clocksource0/current_clocksource ]
	then
		return
	fi

	line_separator
	typeset	-r	timer_name=$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)
	case "$timer_name" in
		"hpet")
			info "Current timer ${GREEN}$timer_name${NORM}."
			LN
			;;

		kvm-clock)
			error "Timer ${RED}kvm-clock${NORM} invalid."
			error "$(hostname -s) must be a physical machine."
			LN
			((++count_errors))
			;;

		*)
			info "Current timer ${RED}$timer_name${NORM}?"
			if grep -q hpet /sys/devices/system/clocksource/clocksource0/available_clocksource
			then
				info "  ==> Enable hpet timer for better performances."
				LN
			else
				info "   hpet timer not available."
				LN
			fi
			;;
	esac
}

typeset -r orarel=${oracle_release%.*.*}

scripts_exists

runInstaller_exists

validate_NFS_exports

[ $test_iso_ol7 == yes ] && ISO_OLinux7_exists || true

validate_gateway

validate_nic

validate_master_time_server

validate_resolv_conf

test_tools

test_if_configure_global_cfg_executed

if [ "$common_user_name" != "no_user_defined" ]
then
	line_separator
	exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"
fi

test_timer_hpet

line_separator
if [ $count_errors -ne 0 ]
then
	error "Configuration failed : $count_errors errors."
	LN
	exit 1
else
	info "Configuration [$OK]"
	LN
	exit 0
fi
