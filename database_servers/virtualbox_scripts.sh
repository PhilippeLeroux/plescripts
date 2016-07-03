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

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path

typeset -r shared_directory=~/plescripts/database_servers/${db}

typeset -ri max_nodes=$(ls -1 $cfg_path/node*|wc -l)

typeset -r shared_path=$shared_directory/vms_virtualbox
[ -d $shared_path ] && exec_cmd rm -rf $shared_path
exec_cmd mkdir $shared_path

typeset -r shared_clone=$shared_directory/vms_virtualbox/clone
exec_cmd mkdir $shared_clone

if [ $max_nodes -gt 1 ]
then
	typeset -r shared_single=$shared_directory/vms_virtualbox/single
	exec_cmd mkdir $shared_single
fi

function clone_scripts
{
	line_separator
	typeset -r	script_name=$shared_clone/clone_${db}_from_orclmaster.sh
	typeset 	first_node_name=undef

	for i in $( seq 1 $max_nodes )
	do
		node_type=$(cat $cfg_path/node${i} | cut -d: -f1)
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $node_type = rac ] && vmmemory_mb=$vm_memory_mb_for_rac_db || vmmemory_mb=$vm_memory_mb_for_single_db

		[ $i -eq 1 ] && printf "#!/bin/sh\n\n" > $script_name

		cat <<EOS >> $script_name
echo "Clone $node_name from $master_name"
VBoxManage clonevm "${master_name}" --name "$node_name" --basefolder "$vm_path" --register
VBoxManage modifyvm "$node_name" --memory $vmmemory_mb
VBoxManage storageattach "$node_name" --storagectl IDE  --port 1 --device 0 --type dvddrive --medium emptydrive

EOS
		[ $i -eq 1 ] && first_node_name=$node_name
	done

	if [ $max_nodes -gt 1 ]
	then # Les nœuds du RAC sont placés dans une groupe
		typeset -r group_name=$(printf "/%s RAC" $(initcap $db))
		echo "echo \"Create group $group_name\"" >> $script_name
		for i in $( seq 1 $max_nodes )
		do
			node_name=$(cat $cfg_path/node${i} | cut -d: -f2)
			echo "echo \"Add node $node_name to $group_name\"" >> $script_name
			echo "VBoxManage modifyvm \"$node_name\" --groups \"$group_name\"" >> $script_name
		done
		echo "" >> $script_name
	fi

	#	Démarre la première VM.
	[ $first_node_name != undef ] && printf "VBoxManage startvm $first_node_name --type headless\n"  >> $script_name

	exec_cmd chmod ug+x $script_name
	LN

	info "clone script : $script_name"
	LN
}

function start_scripts
{
	line_separator
	typeset script_name=$shared_path/${db}_start.sh

	for i in $( seq 1 $max_nodes )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && printf "#!/bin/sh\n\n" >> "$script_name" || printf "\n" >> "$script_name"
		printf "VBoxManage startvm $node_name --type headless\n" >> "$script_name"

		if [ $max_nodes -gt 1 ]
		then
			printf "#!/bin/sh\n\nVBoxManage startvm $node_name --type headless\n" > "$shared_single/${node_name}_start.sh"

			info "$shared_single/${node_name}_start.sh created."
			LN
		fi
	done

	info "start script : $script_name"
	LN
}

function stop_scripts
{
	line_separator
	typeset script_name="$shared_path/${db}_stop.sh"

	for i in $( seq 1 $max_nodes )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && printf "#!/bin/sh\n\n"  >> "$script_name"|| printf "\n" >> "$script_name"
		printf "VBoxManage controlvm $node_name acpipowerbutton\n" >> "$script_name"

		if [ $max_nodes -gt 1 ]
		then
			printf "#!/bin/sh\n\nVBoxManage controlvm $node_name acpipowerbutton\n" > "$shared_single/${node_name}_stop.sh"
			info "$shared_single/${node_name}_stop.sh created."
			LN
		fi
	done

	info "stop script : $script_name"
	LN
}

function poweroff_scripts
{
	line_separator
	typeset script_name="$shared_path/${db}_poweroff.sh"

	for i in $( seq 1 $max_nodes )
	do
		node_name=$(cat $cfg_path/node${i} | cut -d: -f2)

		[ $i -eq 1 ] && printf "#!/bin/sh\n\n" >> "$script_name" || printf "\n" >> "$script_name"
		printf "VBoxManage controlvm $node_name poweroff\n" >> "$script_name"

		if [ $max_nodes -gt 1 ]
		then
			printf "#!/bin/sh\n\nVBoxManage controlvm $node_name poweroff\n" > "$shared_single/${node_name}_poweroff.sh"
			info "$shared_single/${node_name}_poweroff.sh created."
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

exec_cmd chmod ug+x "$shared_path/*sh"
[ -d $shared_path/single ] && exec_cmd chmod ug+x "$shared_path/single/*sh" || true
LN
