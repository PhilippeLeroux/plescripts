#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME

Configure SELinux pour named et dhcpd.
"

typeset	db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

info "Setup selinux"
exec_cmd "chcon -R -t named_zone_t '/var/named/'"
exec_cmd "chcon -R -t dnssec_trigger_var_run_t '/var/named/'"
LN

line_separator
info "Setup SELinux for named."
exec_cmd "setsebool -P named_write_master_zones true"
exec_cmd "chmod g=rwx /var/named"
LN
