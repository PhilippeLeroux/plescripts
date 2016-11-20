#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset switch_to=undef
typeset	release=R4

typeset -r str_usage=\
"Usage : $ME
	-local|-internet
	[-release=$release]	R3|R4
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

exit_if_param_invalid switch_to "local internet"	"$str_usage"
exit_if_param_invalid release "R3 R4" "$str_usage"

function switch_local_repository
{
	info "Enable local repository"
	exec_cmd "yum-config-manager --disable ol7_UEKR4 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_UEKR3 >/dev/null"
	exec_cmd "yum-config-manager --disable ol7_latest >/dev/null"
	case $release in
		R3)
			exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
			exec_cmd "yum-config-manager --enable local_ol7_UEKR3 >/dev/null"
			;;

		R4)
			exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
			exec_cmd "yum-config-manager --enable local_ol7_UEKR4 >/dev/null"
			;;
	esac
	exec_cmd "yum-config-manager --enable local_ol7_latest >/dev/null"
	LN
}

function switch_internet_repository
{
	info "Enable internet repository"
	exec_cmd "yum-config-manager --disable local_ol7_UEKR4 >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_UEKR3 >/dev/null"
	exec_cmd "yum-config-manager --disable local_ol7_latest >/dev/null"
	exec_cmd "yum-config-manager --enable ol7_UEK${release} >/dev/null"
	exec_cmd "yum-config-manager --enable ol7_latest >/dev/null"
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

exec_cmd "yum makecache"
LN
