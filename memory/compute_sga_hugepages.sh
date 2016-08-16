#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
. ~/plescripts/memory/memorylib.sh

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage="Usage : $ME -sga=<xxxU>
	xxx taille de la sga
	U   unité : G M K"

typeset		sga=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-sga=*)
			sga=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef sga	"$str_usage"

typeset -ri hpage_size_mb=$(to_mb $(get_hugepages_size_kb)K)

typeset -ri hpage_total=$(get_hugepages_total)
typeset -ri hpage_total_mb=$(( $hpage_total * $hpage_size_mb ))
typeset -ri hpage_free=$(get_hugepages_free)
typeset -ri hpage_free_mb=$(( $hpage_free * $hpage_size_mb ))

typeset -r sga_mb=$(to_mb $sga)
typeset -r reserved_pages=5
typeset -r sga_hpages=$(compute "($sga_mb / $hpage_size_mb) + $reserved_pages")

info "Hugepage size  : ${hpage_size_mb}Mb"
info "Hugepage total : $hpage_total pages ${hpage_total_mb}Mb"
info "Hugepage free  : $hpage_free pages ${hpage_free_mb}Mb"
LN

info "${sga_mb}Mb for SGA require $sga_hpages pages"
[ $sga_hpages -gt $hpage_total ] && warning "Not enought pages !"
LN
