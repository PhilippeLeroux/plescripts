#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

################################################################################
#	A déplacer dans global.cfg
typeset	-r	infra_yum_repository_path=/yum/OracleLinux/7.2/os/x86_64
################################################################################

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-copy_iso_path=<chemin sur les ISOs d'installations>]

	Si copy_iso_path est précisé les ISOs seront copiés ici : $infra_yum_repository_path

	Ensuite le repository est synchronisé avec le repository Oracle.	

	Note : exporter via nfs le répertoire $infra_yum_repository_path
" 

info "$ME $@"

typeset	copy_iso_path=skip_iso_copy

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-copy_iso_path=*)
			copy_iso_path=${1##*=}
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

exit_if_param_undef copy_iso_path	"$str_usage"

function copy_oracle_linux_iso
{
	exit_if_dir_not_exists $copy_iso_path
	typeset	-r	working_directory=/tmp/mnt

	if [ ! -d $infra_yum_repository_path ]
	then
		info "Create directory : $infra_yum_repository_path"
		exec_cmd mkdir -p $infra_yum_repository_path
	fi

	if [ ! -d $working_directory ]
	then
		info "Create directory : $working_directory"
		exec_cmd mkdir -p $working_directory
	fi

	for iso_name in $copy_iso_path/*.iso
	do
		info "mount $iso_name"
		exec_cmd mount -ro loop $iso_name $working_directory
		LN
		info "Copy $iso_name to $infra_yum_repository_path"
		exec_cmd rsync -avHPS $working_directory $infra_yum_repository_path
		LN
		exec_cmd umount $working_directory
		LN
	done

	info "Remove $working_directory"
	exec_cmd rm -rf $working_directory
}

[ "$copy_iso_path" != skip_iso_copy ] && copy_oracle_linux_iso

exec_cmd reposync	--newest-only --download_path=$infra_yum_repository_path \
					--repoid=ol7_latest 

exec_cmd createrepo $infra_yum_repository_path
