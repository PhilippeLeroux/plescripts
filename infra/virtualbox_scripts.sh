#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=<str>
Création de tous les scripts permettant de :
	cloner la VM
	démarrer/stopper la VM
	Éteindre la VM"

info "$ME $@"

typeset db=undef

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

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

typeset -r upper_db=$(to_upper $db)

typeset -r cfg_path=~/plescripts/infra/$db
exit_if_dir_not_exists $cfg_path

case $hostvm in
	windows_virtualbox)
		script_ext=bat
		vboxmanage=VBoxManage
		bin_path="set PATH=%PATH%;\"$vm_binary_path\""
		;;

	linux_virtualbox)
		script_ext=sh
		vboxmanage=vboxmanage
		bin_path="#no path to define."
		;;

	*)
		error "$hostvm not supported."
		exit 1
		;;
esac

[ ! -d $shared_directory/vms_virtualbox ] && exec_cmd mkdir $shared_directory/vms_virtualbox

typeset -r shared_path=$shared_directory/vms_virtualbox/$upper_db
[ -d $shared_path ] && exec_cmd rm -rf $shared_path
exec_cmd mkdir $shared_path

typeset -r shared_clone=$shared_directory/vms_virtualbox/$upper_db/clone
exec_cmd mkdir $shared_clone

typeset -r shared_single=$shared_directory/vms_virtualbox/$upper_db/single
exec_cmd mkdir $shared_single

typeset -ri max_nodes=$(ls -1 $cfg_path/node*|wc -l)

function clone_scripts
{
	line_separator
	typeset -r	script_name=$shared_clone/clone_${db}_from_orclmaster.$script_ext
	typeset 	first_node_name=undef

	for i in $( seq 1 $(( $max_nodes )) )
	do
		node_type=$(cat $cfg_path/node${i} | cut -d: -f1)
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $node_type = rac ] && vmmemory_mb=$vm_memory_mb_for_rac_db || vmmemory_mb=$vm_memory_mb_for_single_db

		[ $i -eq 1 ] && echo "$bin_path" > $script_name

		(	echo " "
			echo "mkdir \"$vm_path\\$upper_db\""
			echo "$vboxmanage clonevm ${master_name} --name $node_name --basefolder \"$vm_path\" --groups /$upper_db --register"
			echo "$vboxmanage modifyvm $node_name --memory $vmmemory_mb --groups /$upper_db"
			echo "$vboxmanage storageattach $node_name --storagectl IDE  --port 1 --device 0 --type dvddrive --medium emptydrive"
			# Permet de placer la machine dans un groupe, ca ne marche pas sinon
			echo "$vboxmanage unregistervm $node_name"
			echo "$vboxmanage registervm \"$vm_path\\$upper_db\\${node_name}\\${node_name}.vbox\""
		) >> $script_name
		[ $i -eq 1 ] && first_node_name=$node_name
	done
	[ $first_node_name != undef ] && printf "\n\n$vboxmanage startvm $first_node_name --type headless\n"  >> $script_name

	info "clone script : $script_name"
	LN
}

function start_scripts
{
	line_separator
	typeset script_name=$shared_path/${db}_start.$script_ext

	for i in $( seq 1 $(( $max_nodes )) )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && echo "$bin_path" > $script_name
		echo "$vboxmanage startvm $node_name --type headless" >> $script_name

		if [ $max_nodes -gt 1 ]
		then
			(	echo "$bin_path"
				echo "$vboxmanage startvm $node_name --type headless"
			)	> $shared_single/${node_name}_start.$script_ext
			info "$shared_single/${node_name}_start.$script_ext created."
			LN
		fi
	done

	info "start script : $script_name"
	LN
}

function stop_scripts
{
	line_separator
	typeset script_name=$shared_path/${db}_stop.$script_ext

	for i in $( seq 1 $(( $max_nodes )) )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && echo "$bin_path" > $script_name
		echo "$vboxmanage controlvm $node_name acpipowerbutton" >> $script_name

		if [ $max_nodes -gt 1 ]
		then
			(	echo "$bin_path"
				echo "$vboxmanage controlvm $node_name acpipowerbutton"
			) > $shared_single/${node_name}_stop.$script_ext
			info "$shared_single/${node_name}_stop.$script_ext created."
			LN
		fi
	done

	info "stop script : $script_name"
	LN
}

function poweroff_scripts
{
	line_separator
	typeset script_name=$shared_path/${db}_poweroff.$script_ext

	for i in $( seq 1 $(( $max_nodes )) )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && echo "$bin_path" > $script_name
		echo "$vboxmanage controlvm $node_name poweroff" >> $script_name

		if [ $max_nodes -gt 1 ]
		then
			(	echo "$bin_path"
				echo "$vboxmanage controlvm $node_name poweroff"
			)	> $shared_single/${node_name}_poweroff.$script_ext
			info "$shared_single/${node_name}_poweroff.$script_ext created."
			LN
		fi
	done

	info "poweroff script : $script_name"
	LN
}

clone_scripts
start_scripts
stop_scripts
poweroff_scripts
