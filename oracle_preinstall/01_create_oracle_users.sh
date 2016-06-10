#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset ORCL_RELEASE=undef
typeset ORACLE_RELEASE=undef
typeset db_type=undef

typeset -r str_usage="Usage $0 -release=aa.bb.cc.dd -db_type=[single|rac]"

while [ $# -ne 0 ]
do
	case $1 in
		-releaseoracle=*|-release=*)
			ORACLE_RELEASE=${1##*=}
			shift
			;;

		-db_type=*)
			db_type=${1##*=}
			shift
			;;

		*)
			error "'$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

[ $ORACLE_RELEASE = undef ] &&	$ORACLE_RELEASE=$oracle_release

ORCL_RELEASE=${ORACLE_RELEASE:0:2}

info "Create grid profile."
exec_cmd "cp ~/plescripts/oracle_preinstall/grid_env.template  ~/plescripts/oracle_preinstall/grid_env"
case $db_type in
	rac|raco)
		exec_cmd "sed -i \"s!GRID_HOME=!GRID_HOME=$\GRID_ROOT/app/$ORACLE_RELEASE/grid!\" ~/plescripts/oracle_preinstall/grid_env"
		;;

	single|single_fs)
		exec_cmd "sed -i \"s!GRID_HOME=!GRID_HOME=$\GRID_ROOT/app/grid/$ORACLE_RELEASE!\" ~/plescripts/oracle_preinstall/grid_env"
		;;

	*)
		error "type = '$db_type' invalid."
		LN
		info "$str_usage"
		LN
		exit 1
		;;
esac
LN

typeset -r profile_oracle=/tmp/profile_oracle

info "Create oracle profile."
exec_cmd "sed \"s/RELEASE_ORACLE/${ORACLE_RELEASE}/g\" ~/plescripts/oracle_preinstall/template_profile.oracle | sed \"s/ORA_NLSZZ/ORA_NLS${ORCL_RELEASE}/g\" > $profile_oracle"
LN

. $profile_oracle

if [ x"$GRID_ROOT" = x ]
then
	error "Error GRID_ROOT not define...."
	exit 1
fi


line_separator
info "delete users oracle & grid"
exec_cmd -cont userdel -r oracle
exec_cmd -cont userdel -r grid
LN

line_separator
info "delete all groups"
exec_cmd -cont groupdel oinstall
exec_cmd -cont groupdel dba
exec_cmd -cont groupdel oper
exec_cmd -cont groupdel asmadmin
exec_cmd -cont groupdel asmdba
exec_cmd -cont groupdel asmoper
LN

line_separator
info "create all groups"
exec_cmd groupadd -g 1000 oinstall
#	asmadmin : util pour oracle asm.
exec_cmd groupadd -g 1200 asmadmin
exec_cmd groupadd -g 1201 asmdba
#	asmoper et oper sont facultatifs.
exec_cmd groupadd -g 1202 asmoper
exec_cmd groupadd -g 1203 oper
#
exec_cmd groupadd -g 1250 dba
LN

line_separator
info "remove $GRID_ROOT/"
exec_cmd "rm -rf $GRID_ROOT/*"
LN

. ~/plescripts/oracle_preinstall/make_vimrc_file

line_separator
info "create users grid"
exec_cmd useradd -u 1100 -g oinstall -G dba,asmadmin,asmdba,asmoper -s /bin/ksh -c \"Grid Infrastructure Owner\" grid
exec_cmd cp ~/plescripts/oracle_preinstall/grid_env /home/grid/grid_env
exec_cmd cp template_kshrc /home/grid/.kshrc
[ "$mode_vi" = "no" ] && exec_cmd "sed -i \"s/\<vi\>/emacs/g\" /home/grid/.kshrc"
exec_cmd "sed \"s/RELEASE_ORACLE/${ORACLE_RELEASE}/g\" ./template_profile.grid | sed \"s/ORA_NLSZZ/ORA_NLS${ORCL_RELEASE}/g\" > /home/grid/.profile"
make_vimrc_file "/home/grid/.vimrc"
#exec_cmd "mkdir /home/grid/TOOLS"
#exec_cmd "cp ./grid_TOOLS/* /home/grid/TOOLS/"
exec_cmd "find /home/grid | xargs chown grid:oinstall"
LN

line_separator
info "create user oracle"
exec_cmd useradd -u 1050 -g oinstall -G dba,asmdba,oper -s /bin/ksh -c \"Oracle Software Owner\" oracle
exec_cmd cp ~/plescripts/oracle_preinstall/grid_env /home/oracle/grid_env
exec_cmd cp $profile_oracle /home/oracle/.profile
exec_cmd cp template_kshrc /home/oracle/.kshrc
[ "$mode_vi" = "no" ] && exec_cmd "sed -i \"s/\<vi\>/emacs/g\" /home/oracle/.kshrc"
make_vimrc_file "/home/oracle/.vimrc"
#exec_cmd "mkdir /home/oracle/DB"
#exec_cmd "cp DB/* /home/oracle/DB/"
exec_cmd "find /home/oracle | xargs chown oracle:oinstall"
#exec_cmd "find /home/oracle -name \"*.sh\" -o -name \"*.ksh\" -exec chmod u+x {} \;"
LN

line_separator
info "grid directories"
exec_cmd mkdir -p $GRID_BASE
exec_cmd mkdir -p $GRID_HOME
exec_cmd chown -R grid:oinstall $GRID_ROOT
LN

line_separator
info "oracle directories"
exec_cmd mkdir -p $ORACLE_BASE
exec_cmd mkdir -p $ORACLE_HOME
exec_cmd chown -R oracle:oinstall $ORACLE_BASE
LN

line_separator
info "set full permission for owner & group on $GRID_ROOT"
exec_cmd chmod -R 775 $GRID_ROOT
LN

grep grid_env /root/.bash_profile 1>/dev/null
if [ $? -ne 0 ]
then
	line_separator
	info "Update .bash_profile for root"
	(	echo "if [ -f /home/grid/grid_env ]"
		echo "then"
		echo "    . /home/grid/grid_env"
		echo "    export PATH=\$PATH:$GRID_HOME/bin"
		echo "fi"
	)	>> /root/.bash_profile
	LN
fi

line_separator
info "set password for users oracle & grid"
exec_cmd "printf \"oracle\noracle\n\" | passwd oracle >/dev/null 2>&1"
exec_cmd "printf \"grid\ngrid\n\" | passwd grid >/dev/null 2>&1"
LN

line_separator
exec_cmd "rm ~/plescripts/oracle_preinstall/grid_env"
LN

grep -E "^oracle" /etc/sudoers >/dev/null 2>&1
if [ $? -ne 0 ]
then
	line_separator
	info "Config sudo for user oracle"
	exec_cmd "cp /etc/sudoers /tmp/suoracle"
	exec_cmd "echo \"oracle  ALL=(grid)  NOPASSWD:ALL\" >> /tmp/suoracle"
	exec_cmd "visudo -c -f /tmp/suoracle"
	exec_cmd "mv /tmp/suoracle /etc/sudoers"
	LN
fi
