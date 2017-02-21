#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-force_iface_name=vboxnet#]"

script_banner $ME $*

typeset force_iface_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-force_iface_name=*)
			force_iface_name=${1##*=}
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

#	return 0 $1 exists, else 1
function test_if_iface_exists
{
	typeset -r if_name=$1
	VBoxManage list -l hostonlyifs | grep $if_name >/dev/null 2>&1
}

#	Setup Iface $if_name
function config_iface
{
	typeset -r if_name=$1
	info "Setup Iface $if_name"
	exec_cmd -c "VBoxManage hostonlyif ipconfig $if_name --ip ${infra_network}.1"
}

if [ $force_iface_name != undef ]
then
	test_if_iface_exists $force_iface_name
	if [ $? -eq 0 ]
	then
		info "$force_iface_name exists."
		exit 0
	fi
fi

typeset	-a	ifaces_to_remove

while [ 0 -eq 0 ]	#	For ever
do
	typeset iface_name=$(VBoxManage hostonlyif create | tail -1 | sed "s/.*'\(.*\)'.*$/\1/g")
	[ x"$iface_name" == x ] && error "Command VBoxManage failed." && exit 1 || true

	if [ $force_iface_name == undef ]
	then # Le nom de l'interface n'est pas important.
		config_iface $iface_name
		exit 0
	else # Le nom de l'interface est spécifié.
		if [ $force_iface_name == "$iface_name" ]
		then	#	OK, $iface_name a été crées : configuration.
			config_iface $iface_name
			ret=$?
			for remove_iface in ${ifaces_to_remove[*]}
			do
				exec_cmd "VBoxManage hostonlyif remove $remove_iface"
			done
			exec_cmd "exit $ret"
		else	#	KO, on boucle.
			typeset -i iface_no=${iface_name:${#iface_name}-1}
			typeset -i force_iface_no=${force_iface_name:${#force_iface_name}-1}
			[ $iface_no -ge $force_iface_no ] && ( info "Ne devrait jamais arriver ici"; exit 1 )
			info "Interface créée $iface_name, voulut $force_iface_name"
			ifaces_to_remove+=( $iface_name )
			info "Must be removed :  ${ifaces_to_remove[*]}"
		fi
	fi
done

