#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Ce script vérifie que l'OS host remplie les conditions nécessaires au bon
fonctionnement de la démo."

script_banner $ME $*

typeset db=undef

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

typeset -i count_errors=0

function scripts_exists
{
	line_separator
	info -n "Directory exists '$HOME/plescripts' "
	if [ ! -d "$HOME/plescripts" ]
	then
		info -f "[$KO]"
		error "	must contains all scripts."
		count_errors=count_errors+1
	else
		info -f "[$OK]"
	fi
	LN
}

function runInstaller_exists
{
	info -n "Exist '$HOME/$oracle_install/database/runInstaller' "
	if [ ! -f "$HOME/$oracle_install/database/runInstaller" ]
	then
		info -f "[$KO]"
		error " $HOME/$oracle_install/database must contains Oracle installer."
		count_errors=count_errors+1
	else
		info -f "[$OK]"
	fi

	info -n "Exist '$HOME/$oracle_install/grid/runInstaller' "
	if [ ! -f "$HOME/$oracle_install/grid/runInstaller" ]
	then
		info -f "[$KO]"
		error " $HOME/$oracle_install/grid must contains Grid installer."
		count_errors=count_errors+1
	else
		info -f "[$OK]"
	fi
	LN
}

function _is_exported
{
	typeset -r	directory=$1

	info -n "	- $directory "
	if grep -qE "${directory}\s*${infra_network}.0.*" /etc/exports
	then
		info -f "[$OK]"
	else
		count_errors=count_errors+1
		info -f "[$KO]"
	fi
}

function validate_NFS_exports
{
	info "Validate NFS exports from $client_hostname on network ${infra_network}.0 :"
	_is_exported $HOME/plescripts
	_is_exported $HOME/$oracle_install
	_is_exported $iso_olinux_path
	LN
}

function ISO_OLinux7_exists
{
	line_separator
	info -n "ISO Oracle Linux 7 exists $full_linux_iso_name "
	if [ ! -f "$full_linux_iso_name" ]
	then
		info -f "[$KO]"
		count_errors=count_errors+1
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
	if  grep -q "search\s*$infra_domain" /etc/resolv.conf
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		count_errors=count_errors+1
	fi

	info -n " - Test : nameserver $infra_ip "
	if  grep -q ${infra_ip} /etc/resolv.conf 
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		count_errors=count_errors+1
	fi

	LN
}

function _shell_in_path
{
	line_separator
	info -n "~/plescripts/shell in path "
	if $(test_if_cmd_exists llog)
	then
		info -f "[$OK]"
	else
		info -f "[$KO]"
		count_errors=count_errors+1
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
	info -n "$msg"
	if $(test_if_cmd_exists $cmd)
	then
		info -f "[$OK]"
	else
		if [ $option == yes ]
		then
			info -f -n "[${BLUE}optional${NORM}]"
		else
			count_errors=count_errors+1
			info -f -n "[$KO]"
		fi
		info -f " $cmd_msg"
		[[ $option == no && $distrib == openSUSE ]] && ( exec_cmd -ci cnf $cmd; LN )
	fi
}

function test_tools
{
	_shell_in_path

	_in_path VBoxManage	"Install VirtualVox"
	_in_path nc			"Install nc"
	_in_path ssh		"Install ssh"
	_in_path -o git		"Install git"
	_in_path -o tmux	"Install tmux"
	LN
}

scripts_exists

runInstaller_exists

validate_NFS_exports

ISO_OLinux7_exists

validate_resolv_conf

test_tools

line_separator
exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"

line_separator
info -n "~/plescripts/configure_global.cfg.sh executed "
hn=$(hostname -s)
if [[ "$hn" == "$client_hostname" && "$USER" == "$common_user_name" && x"$vm_path" != x ]]
then
	info -f "[$OK]"
else
	info -f "[$KO]"
	count_errors=count_errors+1
fi
LN

line_separator
if [ $count_errors -ne 0 ]
then
	error "Configuration failed : $count_errors errors."
	exit 1
else
	info "Configuration [$OK]"
	exit 0
fi
