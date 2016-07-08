#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg 
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

# Effectue la commande 2 fois car la première insert et ne met pas de double quote
# alors que la seconde update et met les double quote.
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_priv_file
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_priv_file
LN

exec_cmd ifdown $if_priv_name
exec_cmd ifup $if_priv_name
