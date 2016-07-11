
#	ts=4 sw=4
#/bin/bash

#[ -z plelib_release ] && error "~/plescripts/plelib.sh doit être incluse" && exit 1
. ~/plescripts/disklib.sh

# Ces variables sont initialisées
# lv_first_no
# lv_last_no
# lv_size_gb
# lv_nb
# new_lv_number
#
#	$1 nom du vg
#	$2 préfix du lv
function load_lv_info
{
	typeset -r vg_name=$1
	typeset -r prefix=$2

	#	Lecture des n° du premier et dernier lv existant
	typeset -r lv_list_file=/tmp/w.$$
	lvdisplay -c $vg_name | grep -E "${prefix}[0-9].*" | sort > $lv_list_file
	[ ${PIPESTATUS[0]} -ne 0 ] && exit 1

	typeset -ri file_size=$(ls -l $lv_list_file | awk '{ print $5 }')

	if [ $file_size -ne 0 ]
	then
		lv_first_no=$(head -1 $lv_list_file | sed "s/.*\(..\):${vg_name}.*/\1/g")

		typeset -r last_line=$(tail -1 $lv_list_file)
		lv_last_no=$(echo $last_line | sed "s/.*\(..\):${vg_name}.*/\1/g")

		#	Lecture du nom du dernier lv
		typeset -r last_lv_name=$(echo $last_line | cut -d':' -f 1)

		#	Lecture de la taille du dernier lv
		typeset -r size_kb=$(disk_size_bytes $last_lv_name)

		lv_size_gb=$(echo "scale=0; $size_kb / 1024 / 1024 / 1024" | bc)

		#	Nombre de lv existant
		lv_nb=$(( 10#$lv_last_no - 10#$lv_first_no + 1 ))

		#	N° du premier lv à créer
		new_lv_number=$(( 10#$lv_last_no + 1 ))
	fi

	rm $lv_list_file
}

