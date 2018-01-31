#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME"

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

if [ $USER == oracle ]
then
	typeset	-r	orcl_version=$(read_orcl_release)
	cmd="sudo -iu grid asmcmd lsdg"
else
	typeset	-r	orcl_version=$(cut -d. -f1-2<<<"$(grid_version)")
	cmd="asmcmd lsdg"
fi

info "$(printf "%-8s %13s %13s %13s %13s" DG Total Free Usable %Usable)"
if [ "$orcl_version" == 12.1 ]
then
	while read state type rebal sector block au total_mb free_mb req usable_file_mb offdisks voting name
	do
		[ "$state" == "State" ] && continue || true
		x=$(compute -l1 "($usable_file_mb / $total_mb) * 100")
		info "$(printf "%-8s %10s Mb %10s Mb %10s Mb %8s" $name $(fmt_number $total_mb) $(fmt_number $free_mb) $(fmt_number $usable_file_mb)) $x"
	done<<<"$(eval $cmd)"
elif [ "$orcl_version" == 12.2 ]
then
	while read state type rebal sector lsector block au total_mb free_mb req usable_file_mb offdisks voting name
	do
		[ "$state" == "State" ] && continue || true
		x=$(compute -l1 "($usable_file_mb / $total_mb) * 100")
		info "$(printf "%-8s %10s Mb %10s Mb %10s Mb %8s" $name $(fmt_number $total_mb) $(fmt_number $free_mb) $(fmt_number $usable_file_mb)) $x"
	done<<<"$(eval $cmd)"
else
	error "$orcl_version not supported."
fi
LN
