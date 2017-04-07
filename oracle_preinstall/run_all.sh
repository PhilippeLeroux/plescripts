#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset db_type=undef

typeset	-r	ME=$0
typeset -r	str_usage=\
"Usage $ME -db_type=[single|rac|single_fs]"

while [ $# -ne 0 ]
do
	case $1 in
		-db_type=*)
			db_type=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "'$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_invalid db_type "single rac single_fs" "$str_usage"

fake_exec_cmd cd ~/plescripts/oracle_preinstall
cd ~/plescripts/oracle_preinstall
LN

if [ 0 -eq 1 ]; then
info "Workaround yum error : [Errno 256] No more mirrors to try."
exec_cmd systemctl restart nfs-mountd.service
exec_cmd umount /mnt$infra_olinux_repository_path
timing 2
exec_cmd mount /mnt$infra_olinux_repository_path
timing 2
LN
exec_cmd "~/plescripts/yum/clean_cache.sh"
LN
fi # [ 0 -eq 1 ]; then

exec_cmd "./01_create_oracle_users.sh -release=$oracle_release -db_type=$db_type"
LN

exec_cmd "./02_install_some_rpms.sh"
LN

# $1 rpm name.
function install_cvuqdisk
{
	typeset -r cvuqdisk="$1"
	info "Install cvuqdisk : $(sed "s/.*-\(.*\)-.*/\1/"<<<"$cvuqdisk")"
	# Par défaut le groupe est oinstall, pas besoin d'exporter CVUQDISK_GRP
	LANG=C exec_cmd yum -y -q install $cvuqdisk
	LN
}

if [ $db_type != single_fs ]
then
	if [ "${oracle_release%.*.*}" == "12.1" ]
	then # A partie de la 12.2 plus besoin d'oracleasm.
		install_cvuqdisk cvuqdisk-1.0.9-1.rpm
		exec_cmd "./03_install_oracleasm.sh"
		LN
	else
		install_cvuqdisk cvuqdisk-1.0.10-1.rpm
	fi
fi

exec_cmd "./04_apply_os_prerequis.sh -db_type=$db_type"
LN

exit
