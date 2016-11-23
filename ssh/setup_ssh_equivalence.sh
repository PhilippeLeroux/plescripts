#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-server1=name
	-server2=name
	-user1=name

Établie l'équivalence ssh entre les 2 serveurs pour un compte donné.
Le script doit être exécuter depuis $client_hostname, il n'y aura pas de mot de passe
demandé.
"

script_banner $ME $*

typeset	server1=undef
typeset	server2=undef
typeset	user1=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-user1=*)
			user1=${1##*=}
			shift
			;;

		-server1=*)
			server1=${1##*=}
			shift
			;;

		-server2=*)
			server2=${1##*=}
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

exit_if_param_undef server1	"$str_usage"
exit_if_param_undef server2	"$str_usage"
exit_if_param_undef user1	"$str_usage"

function test_if_server_up
{
	typeset	-r	server_name="$1"

	info -n "$server_name up : "
	if ping -c 1 $server_name >/dev/null 2>&1
	then
		info -f	"[$OK]"
		return 0
	else
		info -f "[$KO]"
		return 1
	fi
}

function gen_and_copy_server_pub_key
{
	typeset	-r	from=$1
	typeset	-r	to=$2

	typeset -r public_key=$(get_public_key_for $from)
	info "Copy la clef public de $from dans le known_hosts de $to"
	exec_cmd -c "ssh -t $user1@$to sed -i '/${from}/d' .ssh/known_hosts"
	exec_cmd "ssh -t $user1@$to \"echo \\\"$public_key\\\" >> .ssh/known_hosts\""
	LN
}

function gen_and_copy_user_pub_key
{
	typeset	-r	from=$1
	typeset	-r	to=$2

	info "Génération de la clef pour $user1 sur le serveur $from"
	exec_cmd "ssh -t $user1@$from \"[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \\\"\\\" -f ~/.ssh/id_rsa\" || true"
	LN

	info -n "Lecture de la clef publique de $user1@$from : "
	typeset -r public_key=$(ssh $user1@$from cat .ssh/id_rsa.pub)
	if [ x"$public_key" == x ]
	then
		info -f "[$KO]"
		error "Impossible de lire la clef publique."
		exit 1
	else
		info -f "[$OK]"
		LN
	fi

	info "Ajoute la clef de $from dans les clefs autorisées de $to"
	exec_cmd -c "ssh -t $user1@$to sed -i '/${user1}@${from}.${infra_domain}/d' .ssh/authorized_keys"
	exec_cmd "ssh -t $user1@$to \"echo \\\"$public_key\\\" >> .ssh/authorized_keys\""
	LN
}

must_be_executed_on_server "$client_hostname"

line_separator
typeset -i	nr_server_down=0
test_if_server_up $server1
[ $? -ne 0 ] && nr_server_down=nr_server_down+1

test_if_server_up $server2
[ $? -ne 0 ] && nr_server_down=nr_server_down+1

[ $nr_server_down -ne 0 ] && exit 1
LN

info "setup ssh equivalence for $user1 between $server1 & $server2"
LN

line_separator
gen_and_copy_server_pub_key $server1 $server2
gen_and_copy_server_pub_key $server2 $server1
LN

line_separator
gen_and_copy_user_pub_key $server1 $server2
gen_and_copy_user_pub_key $server2 $server1
