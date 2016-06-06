#!/bin/sh

#	ts=4 sw=4

#	Seul root peut exécuter ce script
#	Permet d'établir les équivalences ssh nécessaires pour un cluster RAC.

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

#	Génération de la clef pour les utilisateur oracle ou grid
#	$1 == oracle|grid
function gen_keys_for_dbuser
{
	typeset -r dbuser=$1

	line_separator
	info "Génération de la clef public pour ${dbuser}"
	exec_cmd "[ ! -d /home/${dbuser}/.ssh ] && su - ${dbuser} -c \"mkdir /home/${dbuser}/.ssh\" || true"
	exec_cmd su - ${dbuser} -c \"[ ! -f /home/${dbuser}/.ssh/id_rsa ] \&\& ssh-keygen -t rsa -N \\\"\\\" -f /home/${dbuser}/.ssh/id_rsa \|\| true\"
	LN

}

#	Génération des clefs publics pour les utilisateurs root, oracle et grid.
function ssh_keygen_local_users
{
	line_separator
	info "Génération de la clef public pour root"
	exec_cmd "[ ! -d ~/.ssh ] && mkdir ~/.ssh || true"
	exec_cmd "[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa || true"
	LN

	gen_keys_for_dbuser oracle

	gen_keys_for_dbuser grid
}

#	$1 nom du serveur sur lequel copier la clef public de root.
function copy_root_rsa_pub_to
{
	typeset -r server_name=$1

	line_separator
	info "Copy public key of $USER:$(hostname -s) on $USER@$server_name"
	exec_cmd ssh-copy-id -i ~/.ssh/id_rsa.pub $server_name
	LN
}

#	$1 nom du serveur ou copier la clef public.
#	$2 nom de l'utilisateur oracle ou grid.
function copy_user_rsa_pub_to
{
	typeset -r server_name=$1
	typeset -r user_name=$2

	typeset -r fqdn_name=$(hostname)

	line_separator
	info "Copy public key of $user_name:$(hostname -s) on $user_name@$server_name"
	exec_cmd -c "ssh $server_name \"sed -i '/^.*${user_name}@${fqdn_name}$/d' /home/$user_name/.ssh/authorized_keys 2>/dev/null\""
	exec_cmd scp /home/$user_name/.ssh/id_rsa.pub $server_name:/home/$user_name/.ssh/add_rsa.pub
	exec_cmd ssh $server_name "\"cat /home/$user_name/.ssh/add_rsa.pub >> /home/$user_name/.ssh/authorized_keys\""
	exec_cmd ssh $server_name "rm -f /home/$user_name/.ssh/add_rsa.pub"
	LN
}

#	Établie l'auto équivalence SSH pour l'utilisateur $1
function auto_equi_for_user
{
	typeset -r user_name=$1
	typeset -r local_server=$(hostname)

	line_separator
	info "Auto equivalence for $user_name"
	exec_cmd -c "sed -i '/^.*${user_name}@${local_server}$/d' /home/$user_name/.ssh/authorized_keys 2>/dev/null"
	exec_cmd "cat /home/$user_name/.ssh/id_rsa.pub >> /home/$user_name/.ssh/authorized_keys"
	LN
}

#	Met à jour le fichier locale know_host avec le serveur $1
#	Le fichier est mis à jour pour les utilisateurs root, oracle et grid du serveur $1
function update_local_know_hosts_with
{
	typeset -r remote_server=$1

	typeset -r local_server=$(hostname -s)

	local_keyscan=$(ssh-keyscan -t ecdsa $local_server | tail -1)
	remote_keyscan=$(ssh-keyscan -t ecdsa $remote_server | tail -1)

	line_separator
	info "update known_hosts for root"
	exec_cmd -c "sed -i '#^${local_server}.*#d' ~/.ssh/known_hosts 2>/dev/null"
	exec_cmd -c "sed -i '#^${remote_server}.*#d' ~/.ssh/known_hosts 2>/dev/null"
	exec_cmd "echo \"$local_keyscan\" >> ~/.ssh/known_hosts"
	exec_cmd "echo \"$remote_keyscan\" >> ~/.ssh/known_hosts"
	LN

	typeset -r user_list="grid oracle"
	for u in $user_list
	do
		info "update known_hosts for $u"
		exec_cmd -c "sed -i '/^${local_server}.*/d' /home/$u/.ssh/known_hosts 2>/dev/null"
		exec_cmd -c "sed -i '/^${remote_server}.*/d' /home/$u/.ssh/known_hosts 2>/dev/null"
		exec_cmd "echo \"$local_keyscan\" >> /home/$u/.ssh/known_hosts"
		exec_cmd "echo \"$remote_keyscan\" >> /home/$u/.ssh/known_hosts"
		exec_cmd "chown -R $u:oinstall /home/$u/.ssh/"
		LN
	done
}

#	============================================================
#	MAIN
#	============================================================
typeset -r str_usage=\
"Usage : $0 -remote_server=<str>
	Ce script doit être exécuté sur tous les noeuds d'un cluster RAC.
	Met en place les connections ssh des utilisateurs grid et oracle
	ainsi que root."

typeset remote_server=undef

while [ $# -ne 0 ]
do
	case $1 in
		-remote_server=*)
			remote_server=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			LN
			exit 1
			;;
	esac
done

exit_if_param_undef remote_server	"$str_usage"

[ $USER != root ] && error "Only root user can execute this script !" && exit 1

info "ssh connection between $(hostname -s) and $remote_server"
LN

update_local_know_hosts_with	$remote_server
LN

ssh_keygen_local_users
LN

copy_root_rsa_pub_to	$remote_server
LN

copy_user_rsa_pub_to	$remote_server oracle
auto_equi_for_user		oracle
LN

copy_user_rsa_pub_to	$remote_server grid
auto_equi_for_user		grid
LN

