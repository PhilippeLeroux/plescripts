#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME
	[-restore|-backup]  -restore config, -backup config
	[-skip_vim]         with -restore not install gvim
	[-emul]
"

typeset	action=undef
typeset	install_gvim=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-backup)
			action=backup
			shift
			;;

		-restore)
			action=restore
			shift
			;;

		-skip_vim)
			install_gvim=no
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

if [ $action == undef ]
then
	error "Missing parameter -restore or -backup"
	LN
	info "$str_usage"
	LN
	exit 1
fi

function apply_sudo_config
{
	typeset	-r	sudo_config="$USER ALL=(root) NOPASSWD: ALL"
	typeset	-r	sudo_file=" /etc/sudoers.d/90_$USER"

	line_separator
	info "Config sudo for user $USER"
	exec_cmd "sudo sh -c \"echo '$sudo_config' > $sudo_file\""
	LN
	exec_cmd "sudo visudo -c -f $sudo_file"
	LN
}

function restore
{
	[ "$USER" != root ] && apply_sudo_config || true

	line_separator
	if grep -q "set editing-mode vi" /etc/inputrc
	then
		info "mode vi is enabled."
	else
		info "enable mode vi"
		exec_cmd "sed \"1i set editing-mode vi\" /etc/inputrc > new_inputrc"
		#exec_cmd "cat ~/plescripts/setup_first_vms/for_inputrc /etc/inputrc > new_inputrc"
		exec_cmd "sudo mv new_inputrc /etc/inputrc"
	fi
	LN

	line_separator
	info "Apply bashrc extensions :"
	exec_cmd "sed -i \"/^.*bashrc_extensions.*$/d\" ~/.bashrc"
	exec_cmd "echo \"[ -f ~/plescripts/myconfig/bashrc_extensions ] && . ~/plescripts/myconfig/bashrc_extensions || true\" >> ~/.bashrc"
	LN

	typeset	gvim_installed=no

	if command_exists gvim
	then
		install_gvim=no
		gvim_installed=yes
		line_separator
		info "gvim is installed."
		LN
	fi

	if [ $install_gvim == yes ]
	then
		line_separator
		. /etc/os-release
		case "$ID" in
			opensuse)
				exec_cmd -c "sudo zypper install git-core gvim"
				[ $? -eq 0 ] && gvim_installed=yes || true
				;;

			neon)
				exec_cmd "sudo apt install vim-gnome"
				[ $? -eq 0 ] && gvim_installed=yes || true
				;;

			*)
				warning "$PRETTY_NAME : install gvim yourself."
				;;
		esac
		LN
	fi

	if [ $gvim_installed == yes ] || command_exists vim
	then
		line_separator
		info "[G]vim configuration :"
		exec_cmd "~/plescripts/myconfig/vim_config.sh -restore"
		LN
	fi

	line_separator
	info "tmux configuration :"
	exec_cmd cp mytmux.conf ~/.tmux.conf
	LN

	case "$USER" in
		root|oracle|grid)
			: # do nothing
			;;

		*)
			if [ ! -h ~/plescripts ]
			then
				line_separator
				exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"
				LN
			fi
			;;
	esac
}

function backup
{
	line_separator
	info "Backup bashrc extensions :"
	exec_cmd cp ~/.bashrc_extensions ~/plescripts/myconfig/bashrc_extensions
	LN

	line_separator
	info "Backup [G]vim configuration :"
	exec_cmd "~/plescripts/myconfig/vim_config.sh -backup"
	LN

	line_separator
	info "tmux configuration :"
	exec_cmd cp ~/.tmux.conf ~/plescripts/myconfig/mytmux.conf
	LN
}

[ $action == restore ] && restore || backup
