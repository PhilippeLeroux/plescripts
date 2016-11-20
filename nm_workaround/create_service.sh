#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -role=infra|master

Suite à une mise à jour les zones ne sont plus présentes au boot.
Un script les actives au démarrage.
"

script_banner $ME $*

typeset	role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-role=*)
			role=${1##*=}
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

exit_if_param_invalid role "infra master" "$str_usage"

cat <<EOS > /root/nm_workaround.sh
#!/bin/bash

echo "add $if_pub_name to zone trusted"
nmcli connection modify $if_pub_name connection.zone trusted
echo "add $if_iscsi_name to zone trusted and set mtu to 9000"
nmcli connection modify $if_iscsi_name connection.zone trusted ethernet.mtu 9000
echo
EOS

if [ $role == master ]
then
	cat <<-EOS >> /root/nm_workaround.sh
	echo "add $if_rac_name to zone trusted"
	nmcli connection modify $if_rac_name connection.zone trusted ethernet.mtu 9000
	exit 0 #	Si $if_rac_name n'existe pas le script ne termine pas en erreur.
	EOS
else
	cat <<-EOS >> /root/nm_workaround.sh
	echo "add $if_net_name to zone public"
	nmcli connection modify $if_net_name connection.zone public
	EOS
fi

exec_cmd cat /root/nm_workaround.sh
LN

exec_cmd "chmod u+x /root/nm_workaround.sh"
LN

if [ -f /usr/lib/systemd/system/nm_workaround.service ]
then
	exec_cmd -c "systemctl stop nm_workaround"
	exec_cmd -c "systemctl disable nm_workaround"
	LN
fi

fake_exec_cmd make /usr/lib/systemd/system/nm_workaround.service[...]
LN
cat <<EOS >/usr/lib/systemd/system/nm_workaround.service
[Unit]
Description=Network Manager workaround
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/root/nm_workaround.sh

[Install]
WantedBy=multi-user.target
EOS

exec_cmd "systemctl enable nm_workaround"
exec_cmd "systemctl start nm_workaround"
timing 5 "Wait nm_workaround started"
exec_cmd "systemctl status nm_workaround -l"
LN
