#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

info "Running : $ME $*"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset tuned_path=/usr/lib/tuned/ple-oracle
typeset tuned_conf=$tuned_path/tuned.conf

exec_cmd "mkdir $tuned_path"

cat <<EOS>$tuned_conf
#
# tuned configuration
#

[main]
include=virtual-guest

[sysctl]
#	Redhat advises
#swappiness=0 fait souvent planter l'instance du master.
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 80
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
EOS

info "Create tuned profile : ple-oracle"
exec_cmd "cat $tuned_conf"
LN

info "Active le profile ple-oracle"
exec_cmd "tuned-adm profile ple-oracle"
LN
