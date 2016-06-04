#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

role=${1-rdbms}

# Pour el6 c'est nmap
line_separator
exec_cmd -c yum -y install	nmap-ncat	\
							git			\
							~/plescripts/rpm/figlet-2.2.5-9.el6.x86_64.rpm
LN

exec_cmd "~/plescripts/gadgets/customize_logon.sh"

if [ $role = rdbms ]
then
	exec_cmd "su - grid -c \"~/plescripts/shell/vim_plugin -init\""
	exec_cmd "cp -pr /home/grid/.vim /home/oracle"
	exec_cmd "chown -R oracle:oinstall /home/oracle/.vim"
	LN
else
	exec_cmd "~/plescripts/shell/vim_plugin -init"
fi
LN
