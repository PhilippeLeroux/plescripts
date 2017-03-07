#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Ce script vérifie que le virtual-host remplie les conditions nécessaires au bon
fonctionnement de la démo."

script_banner $ME $*

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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
	info -n "Directory exists '$HOME/plescripts' "
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
	info "Oracle extracted :"
	info -n "Exist '$HOME/$oracle_install/database/runInstaller' "
	if [ ! -f "$HOME/$oracle_install/database/runInstaller" ]
	then
		info -f "[$KO]"
		error " $HOME/$oracle_install/database must contains Oracle installer."
		LN
		((++count_errors))
	else
		info -f "[$OK]"
		LN
	fi

	if [ "$orarel" == "12.2" ]
	then
		info "Grid zip :"
		info -n "Exist '$HOME/$oracle_install/grid/linuxx64_12201_grid_home.zip' "
		if [ ! -f "$HOME/$oracle_install/grid/linuxx64_12201_grid_home.zip" ]
		then
			info -f "[$KO]"
			error " $HOME/$oracle_install/grid must contains linuxx64_12201_grid_home.zip."
			LN
			((++count_errors))
		else
			info -f "[$OK]"
			LN
		fi
	elif [ "$orarel" == "12.1" ]
	then
		info "Grid extracted :"
		info -n "Exist '$HOME/$oracle_install/grid/runInstaller' "
		if [ ! -f "$HOME/$oracle_install/grid/runInstaller" ]
		then
			info -f "[$KO]"
			error " $HOME/$oracle_install/grid must contains Grid installer."
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

	info -n "	- $directory "
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
		info "\tadd to /etc/exports : $HOME/plescripts $network/$if_pub_prefix(rw,async,no_root_squash,no_subtree_check)"
	fi
	if ! _is_exported $HOME/$oracle_install
	then
		info "\tadd to /etc/exports : $HOME/oracle_install/$orarel $network/$if_pub_prefix(ro,async,no_root_squash,no_subtree_check)"
	fi
	LN
}

function ISO_OLinux7_exists
{
	line_separator
	info -n "ISO Oracle Linux $OL7_LABEL exists $full_linux_iso_name"
	if [ ! -f "$full_linux_iso_name" ]
	then
		info -f "[$KO]"
		((++count_errors))
	else
		info -f "[$OK]"
	fi
	LN
}

function validate_dns_main
{
	line_separator
	info -n "Validate main DNS $dns_main "

	if ping -c 1 $dns_main >/dev/null 2>&1
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		((++count_errors))
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
	info -n "\$PATH contains ~/plescripts/shell "
	if $(test_if_cmd_exists stop_vm)
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

	typeset -r	distrib=$(grep ^NAME /etc/os-release | cut -d= -f2)

	typeset -r msg=$(printf "%-10s " $cmd)
	info -n "  $msg"
	if $(test_if_cmd_exists $cmd)
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
		if [[ $option == no && $distrib == openSUSE ]]
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
		info "Errors :$errors_msg"
	else
		info -f "[$OK]"
	fi
	LN
}

typeset -r orarel=${oracle_release%.*.*}

scripts_exists

runInstaller_exists

validate_NFS_exports

ISO_OLinux7_exists

validate_dns_main

validate_resolv_conf

test_tools

test_if_configure_global_cfg_executed

line_separator
exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"

line_separator
if [ $count_errors -ne 0 ]
then
	error "Configuration failed : $count_errors errors."
	exit 1
else
	info "Configuration [$OK]"
	exit 0
fi
