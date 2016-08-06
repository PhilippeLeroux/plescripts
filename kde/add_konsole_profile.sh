#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

line_separator
info "$(date +"%Y/%m/%d") : Running on $(hostname)"

typeset db=undef
typeset remove_existing_profiles=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-clean)
			remove_existing_profiles=yes
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

typeset -r profile_path=~/.kde4/share/apps/konsole
[ ! -d $profile_path ] && error "'$profile_path' not exists." && exit 1

if [ "$db" = "undef" ]
then
	info "Remove existing profile :"
	exec_cmd "rm $profile_path/srv*.profile"
	LN
	exit 0
fi

typeset -r db_path=~/plescripts/database_servers/${db}
[ ! -d $db_path ] && error "'$db_path' not exists." && exit 1

typeset -r node_file_prefix=${db_path}/node

typeset -ri max_nodes=$(ls -1 $db_path/node* | wc -l)

function create_profile
{
	typeset -r	db=$1
	typeset -ri	inode=$2
	typeset -r	account=$3

	typeset -r server_name=$(cat $node_file_prefix$inode | cut -d':' -f2)
	typeset -r profile_file=$profile_path/${server_name}_${account}.profile

	info "Create profile : $profile_file."

	(	echo "[General]"
		echo "Command=/bin/bash -c \"/usr/bin/ssh -Y $account@$server_name\""
		echo "Name=$server_name : $account"
		echo "Parent=FALLBACK/"
		echo "StartInCurrentSessionDir=false"
	)	> $profile_file
}

if [ $remove_existing_profiles = yes ]
then
	info "Remove existing profile :"
	exec_cmd "rm $profile_path/srv*.profile"
	LN
fi

for inode in $( seq 1 $max_nodes )
do
	create_profile $db $inode root
	create_profile $db $inode grid
	create_profile $db $inode oracle
done
LN

