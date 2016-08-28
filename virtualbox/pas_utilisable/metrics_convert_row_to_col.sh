#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -i=<input file> -o=<output file>"

info "Running : $ME $*"

typeset input=undef
typeset output=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-i=*)
			input=${1##*=}
			shift
			;;

		-o=*)
			output=${1##*=}
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

exit_if_file_not_exists "$input" "$str_usage"

typeset -r vm_metrics="Net/Rate/Rx,Net/Rate/Tx,CPU/Load/User,CPU/Load/Kernel,RAM/Usage/Used,Disk/Usage/Used"

function clean_up_metric
{
	read value unit<<<"$1"

	case "$unit" in
		kB)
			convert_2_bytes ${value}k
			;;

		mB)
			convert_2_bytes ${value}m
			;;

		"B/s")
			echo $value
			;;

		*)	# Pas d'unité, c'est un %tage, suppression du symbole %
			echo ${value:0:${#value}-1}
			;;
	esac
}

#	Ecriture des metrics.
typeset -i	line_count=0
typeset		prev_tt=first_loop
typeset		metric_value_list
while read timestamp vm_name metric_name metric_value
do
	if [ $prev_tt == $timestamp ]
	then	# tt correspondant au même tt que la précédente ligne.
		metric_value_list="$metric_value_list $(clean_up_metric $metric_value)"
	else	# Nouveau tt ou pas de tt (première passe dans la boucle)
		#	Ecriture des métrics du tt précédent.
		[ x"$metric_value_list" != x ] && echo "$metric_value_list"

		#	Initialisation du nouveau tt.
		metric_value_list="${timestamp%%.*} $vm_name $(clean_up_metric $metric_value)"
		prev_tt=$timestamp
	fi
	line_count=line_count+1
done<<<"$(grep -vE "(^------------|^Time)" $input)" > "$output"
