#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

role=${1-rdbms}

line_separator
exec_cmd -c yum -y install	nmap-ncat	\
							git			\
							~/plescripts/rpm/figlet-2.2.5-9.el6.x86_64.rpm
LN

exec_cmd "~/plescripts/gadgets/customize_logon.sh"

if [ $role = rdbms ]
then
	if [ -f /root/plescripts/gadgets/vim.tar.gz ]
	then
		#	Installation des plugins vim pour oracle & grid
		exec_cmd "gzip -dc /root/plescripts/gadgets/vim.tar.gz | tar xf - -C /home/oracle"
		exec_cmd "chown -R oracle:oinstall /home/oracle/.vim"
		exec_cmd "gzip -dc /root/plescripts/gadgets/vim.tar.gz | tar xf - -C /home/grid"
		exec_cmd "chown -R grid:oinstall /home/grid/.vim"
		LN
	else # Si vim.tar.gz disparaît du dépôt ça fonctionnera encore.
		exec_cmd "su - oracle -c \"~/plescripts/shell/vim_plugin -init\""
		exec_cmd "su - grid -c \"~/plescripts/shell/vim_plugin -init\""
	fi
else
	exec_cmd "~/plescripts/shell/vim_plugin -init"
fi
LN
