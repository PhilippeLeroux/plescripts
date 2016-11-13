#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

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

typeset	-i	count_checks=0
typeset	-i	count_errors=0

#	$1	message
#	$@	arguments for cluvfy
function run_cluvfy
{
	typeset	-r	message="$1"
	shift 1
	typeset	-r	log_name=/tmp/"$(echo "$message" | tr ' ' '_' | tr '/' '-')".log

	count_checks=count_checks+1

	info "$count_checks : $message"

	exec_cmd -c "cluvfy $@ > $log_name 2>&1"
	if [ $? -ne 0 ]
	then
		count_errors=count_errors+1
		warning "Check log : $log_name"
	fi
	LN
}

run_cluvfy "checks reachability between nodes" comp nodereach -n all
run_cluvfy "checks node connectivity" comp nodecon
if [ $rac_orcl_fs == ocfs2 ]
then
	run_cluvfy "checks CFS integrity" comp cfs -n all -f /$ORCL_DISK
fi

#run_cluvfy "checks shared storage accessibility" comp ssa
#run_cluvfy "checks space availability" comp space
#run_cluvfy "checks minimum system requirements" comp sys

run_cluvfy "checks cluster integrity" comp clu
run_cluvfy "checks cluster manager integrity" comp clumgr
run_cluvfy "checks OCR integrity" comp ocr
run_cluvfy "checks OLR integrity" comp olr
run_cluvfy "checks HA integrity" comp ha
run_cluvfy "checks free space in CRS Home" comp freespace
run_cluvfy "checks CRS integrity" comp crs
run_cluvfy "checks node applications existence" comp nodeapp

#run_cluvfy "checks administrative privileges" comp admprv
#run_cluvfy "compares properties with peers" comp peer

run_cluvfy "checks software distribution" comp software

#run_cluvfy "checks ACFS integrity" comp acfs

run_cluvfy "checks ASM integrity" comp asm
run_cluvfy "checks GPnP integrity" comp gpnp

#run_cluvfy "checks GNS integrity" comp gns -postcrsinst

run_cluvfy "checks SCAN configuration" comp scan
run_cluvfy "checks OHASD integrity" comp ohasd
run_cluvfy "checks Clock Synchronization" comp clocksync
run_cluvfy "checks Voting Disk configuration and UDEV settings" comp vdisk
run_cluvfy "checks mandatory requirements and/or best practice recommendations" comp healthcheck

#run_cluvfy "checks DHCP configuration" comp dhcp
#run_cluvfy "checks DNS configuration" comp dns

#	Produit un fichier XML de comparaison.
#run_cluvfy "collect and compare baselines" comp baseline -collect all

if [ $count_errors -ne 0 ]
then
	warning "$count_errors/$count_checks checks failed."
else
	info "All checks passed."
fi
