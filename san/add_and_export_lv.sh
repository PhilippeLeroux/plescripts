#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
. ~/plescripts/disklib.sh
. ~/plescripts/san/lvlib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-export_to=\"srv1 srv2 ...\" : Liste des serveurs, séparés par un espace, ou doivent être exportées les LUNs (1)
	-initiator_name=name         : nom de l'initiateur si export_to n'est pas spécifié.
	-vg_name=name                : nom du VG.
	-prefix=name                 : préfixe du LV si export_to n'est pas spécifié.
	-count=#                     : nombre de LV à ajouter dans le VG $vg_name
	[-size_gb=#]                 : taille des LV, si omis prend la taille de la dernière LUN

	[-no_backup]                 : A utiliser quand le backup est effectué par un autre script.


	(1) Si -export_to est spécifié les paramètres -initiator_name et -prefix
	seront obtenu grâce au nom du serveur.
	Si plus de 1 serveur, les noms doivent correspondre aux noms des nœuds d'un RAC.

Actions :
	1) Création des LV dans le VG.
	2) Export des LV"

typeset		export_to=undef
typeset		initiator_name=undef
typeset		vg_name=undef
typeset		prefix=undef
typeset	-i	count=-1
typeset -i	size_gb=-1
typeset		do_backup=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-export_to=*)
			export_to=${1##*=}
			shift
			;;

		-initiator_name=*)
			initiator_name=${1##*=}
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
			shift
			;;

		-prefix=*)
			prefix=${1##*=}
			shift
			;;

		-count=*)
			count=${1##*=}
			shift
			;;

		-size_gb=*)
			size_gb=${1##*=}
			shift
			;;

		-no_backup)
			do_backup=no
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

if [ "$export_to" == undef ]
then
	exit_if_param_undef initiator_name	"$str_usage"
	exit_if_param_undef prefix			"$str_usage"
else
	if [[ $initiator_name != undef || $prefix != undef ]]
	then
		error "Don't use -initiator_name or -prefix with -export_to."
		LN
		info "$str_usage"
	fi
fi
exit_if_param_undef vg_name			"$str_usage"
exit_if_param_undef count			"$str_usage"

function get_vg_free_gb # $1 vg_name
{
	typeset -r p_vg_name=$1

	IFS=':' read name rw f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 pe_size_kb total_pe alloc_pe free_pe rem<<<$(vgdisplay -c $p_vg_name 2>/dev/null)
	free_lv_size_gb=$(( $free_pe * $pe_size_kb / 1024 /1024 ))
	echo $free_lv_size_gb
}

#	============================================================
if [ "$export_to" != undef ]
then	#	Déduction du préfixe à partir du nom du premier serveur.
	typeset first_server_name=$(echo $export_to | cut -d\  -f1)
	[ x"$first_server_name" == x ] && first_server_name=$export_to || true
	# Le nom des serveurs est de la forme srv.*## (## 01 02 03...)
	read prefix num_node <<<"$( sed "s/srv\(.*\)[0-9]\{2\}$/\1/" <<< "$first_server_name" )"
	info "Read prefix '$prefix' from '$first_server_name'"
fi

#	Ces variables sont initialisées par load_lv_info
typeset lv_first_no=0
typeset lv_last_no=0
typeset lv_size_gb=0
typeset lv_nb=0
typeset new_lv_number=0

load_lv_info $vg_name $prefix
[ $size_gb -ne -1 ] && lv_size_gb=$size_gb

if [ $lv_nb -eq 0 ]
then	# Il n'existe pas de LV.
	if [ $size_gb -eq -1 ]
	then	# Donc la taille des disques à créer doit être précisée.
		error "No existing LUNs : use -size_gb"
		exit 1
	fi

	lv_first_no=01
	lv_last_no=$(printf "%02d" $count)
	lv_nb=$count
	lv_size_gb=$size_gb
	new_lv_number=$lv_first_no
fi

info "Exists $lv_nb disks from $lv_first_no to $lv_last_no"
info "Add $count disks of ${lv_size_gb}Gb, start at $new_lv_number"

#	Vérifie s'il y a suffisamment de place dans le VG
free_vg_gb=$(get_vg_free_gb $vg_name)
need_gb=$(( $count * $lv_size_gb ))

info "Need ${need_gb}Gb, available ${free_vg_gb}Gb"
if [ $need_gb -gt $free_vg_gb ]
then
	error "Not enougth space."
	exit 1
fi
LN

exec_cmd ~/plescripts/san/create_lv.sh	-vg_name=$vg_name			\
										-prefix=$prefix				\
										-size_gb=$lv_size_gb		\
										-first_no=$new_lv_number	\
										-count=$count
LN

for server_name in $export_to
do
	if [ $server_name != undef ]
	then	# Déduction du préfixe et du n° du nœud du nom du serveur.
		read prefix num_node <<<"$( sed "s/srv\(.*\)\([0-9]\{2\}\)$/\1 \2/" <<< "$server_name" )"
		initiator_name=$(get_initiator_for $prefix $num_node)
	fi

	exec_cmd ~/plescripts/san/export_lv.sh	-initiator_name=$initiator_name	\
											-vg_name=$vg_name				\
											-prefix=$prefix					\
											-first_no=$new_lv_number		\
											-count=$count					\
											-no_backup
	LN
done

[ $do_backup == yes ] && exec_cmd ~/plescripts/san/save_targetcli_config.sh -name="after_add_and_export_lv" || true
