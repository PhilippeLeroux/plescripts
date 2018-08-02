#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME

    Lors de l'installation d'une distribution en passant d'abord par la version
    live (démo) puis en installant la version définitive, le serveur DHCP
    n'enregistrera pas le nom du serveur dans le DNS au prochain redémarrage.

    La raison semble être une \"corruption\" du fichier leases qui contient 2
    serveurs avec des noms différents, mais la même adresse MAC.

    Le script va donc :
        - stopper les serveurs DHCPD et NAMED.
        - supprimer le fichier leases et le recréer mais vide.
        - démarrer les serveurs DHCPD et NAMED.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
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

#ple_enable_log -params $PARAMS

typeset	-r	leases_file="/var/lib/dhcpd/dhcpd.leases"

if [ ! -f $leases_file ]
then
	error "File $leases_file not exists."
	LN
	exit 1
fi

info "stop dhcpd and named."
exec_cmd systemctl stop dhcpd
exec_cmd systemctl stop named
LN

info "rm leases_file"
exec_cmd "rm $leases_file"
LN

info "touch leases_file"
exec_cmd "touch $leases_file"
LN

info "start named and dhcpd."
exec_cmd systemctl start named
exec_cmd systemctl start dhcpd
LN
