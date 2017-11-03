#!/bin/bash
# vim: ts=4:sw=4:ft=sh
# ft=sh car la colorisation ne fonctionne pas si le nom du script commence par
# un n°

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset	update_os=yes

typeset -r str_usage=\
"Usage : $ME
	[-update_os=$update_os]	yes or no

Doit être exécuté sur le serveur d'infrastructure ou le master.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-update_os=*)
			update_os=${1##*=}
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

line_separator
info "Setup English for OS logs"
exec_cmd localectl set-locale LANG=en_US.UTF-8
LN

if [ $console_blanking == disable ]
then
	line_separator
	# Désactive la mise en veille de la console, permet de visualiser si une VM est
	# démarrée ou non.
	info "Disable console blanking"
	exec_cmd ~/plescripts/grub2/setup_kernel_boot_options.sh -add="consoleblank=0"
	LN
fi

line_separator
info "Create user $common_user_name"
exec_cmd useradd -g users -M -N -u $common_uid $common_user_name
LN

line_separator
. ~/plescripts/oracle_preinstall/make_vimrc_file	# Charge la fonction make_vimrc_file
make_vimrc_file "/root"

line_separator
exec_cmd "cat ~/plescripts/setup_first_vms/for_inputrc /etc/inputrc > new_inputrc"
exec_cmd mv new_inputrc /etc/inputrc
LN

if [ $update_os == yes ]
then
	if rpm_update_available
	then
		line_separator
		exec_cmd yum -y -q update
		LN
	else
		LN
	fi

	line_separator
	exec_cmd yum -y -q install						\
							nfs-utils				\
							iscsi-initiator-utils	\
							deltarpm				\
							wget					\
							net-tools				\
							vim-enhanced			\
							unzip					\
							tmux					\
							nmap-ncat				\
							git						\
							~/plescripts/rpm/figlet-2.2.5-9.el6.x86_64.rpm
	LN
else
	line_separator
	exec_cmd yum -y -q install ~/plescripts/rpm/figlet-2.2.5-9.el6.x86_64.rpm
	LN
fi

if [ $bug_disable_nfsv4 == yes ]
then
	line_separator
	info "Workaround : disable NFS v4"
	exec_cmd "echo '# PLE' >> /etc/sysconfig/nfs"
	exec_cmd "echo \"RPCNFSDARGS='--no-nfs-version 4'\" >> /etc/sysconfig/nfs"
	LN
fi
