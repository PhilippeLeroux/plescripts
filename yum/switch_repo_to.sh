#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset switch_to=undef
typeset	release=undef

typeset -r str_usage=\
"Usage : $ME
	-local|-internet
	-release=latest|R3|R4|DVD_R2|DVD_R3|DVD_R4]

Activation d'un dépôt.

Le flag -internet ne sert que pour des serveurs de tests.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-release=*)
			release=${1##*=}
			shift
			;;
		
		-local)
			switch_to=local
			shift
			;;

		-internet)
			switch_to=internet
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

if [ "$switch_to" == undef ]
then
	error "Flag -local or -internet missing."
	LN
	info "$str_usage"
	LN
	exit 1
fi

if [ "$release" == undef ]
then
	case "$(hostname -s)" in
		"$infra_hostname")	# Serveur d'infra
			typeset	release=$infra_yum_repository_release
			;;

		"$master_hostname") # Serveur Master.
			typeset	release=$master_yum_repository_release
			;;
	esac
fi

exit_if_param_invalid release "latest R3 R4 DVD_R2 DVD_R3 DVD_R4"	"$str_usage"

function switch_local_repository
{
	info "Enable local repository : $release"
	LN

	exec_cmd "yum-config-manager --disable ol7_UEKR4 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_UEKR3 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_latest >/dev/null"

	case $release in
		latest)
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"

			exec_cmd "yum-config-manager --enable local_ol7_latest >/dev/null"
			;;

		R3)
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"

			exec_cmd "yum-config-manager --enable local_ol7_latest >/dev/null"
			exec_cmd "yum-config-manager --enable local_ol7_UEKR3 >/dev/null"
			;;

		R4)
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"

			exec_cmd "yum-config-manager --enable local_ol7_latest >/dev/null"
			exec_cmd "yum-config-manager --enable local_ol7_UEKR4 >/dev/null"
			;;

		DVD_R2)
			exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"

			exec_cmd "yum-config-manager --enable ol7_DVD_R2 >/dev/null"
			;;

		DVD_R3)
			exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"

			exec_cmd "yum-config-manager --enable ol7_DVD_R3 >/dev/null"
			;;

		DVD_R4)
			exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"

			exec_cmd "yum-config-manager --enable ol7_DVD_R4 >/dev/null"
			;;
	esac
	LN
}

function switch_internet_repository
{
	info "Enable internet repository : $release"
	LN

	exec_cmd "yum-config-manager --disable ol7_DVD_R2 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_DVD_R3 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_DVD_R4 >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"

	exec_cmd "yum-config-manager --enable ol7_latest >/dev/null"
	case $release in
		latest)
			exec_cmd "yum-config-manager --disable ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --disable ol7_UEKR4 >/dev/null"
			;;

		R3)
			exec_cmd "yum-config-manager --disable ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --enable ol7_UEKR3 >/dev/null"
			;;

		R4)
			exec_cmd "yum-config-manager --disable ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --enable ol7_UEKR4 >/dev/null"
			;;
	esac
	LN
}

case $switch_to in
	internet)
		switch_internet_repository
		;;

	local)
		switch_local_repository
		;;
esac

exec_cmd ~/plescripts/yum/clean_cache.sh
LN

exec_cmd yum repolist all
LN
