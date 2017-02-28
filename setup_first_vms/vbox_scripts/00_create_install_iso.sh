#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	keymap=detect
typeset	locale=detect
typeset	timezone=detect
typeset	keep_iso_copy=no
typeset	crypt_root_password=yes

typeset -r str_usage=\
"Usage : $ME
	[-keymap=detect]   Keyboard mapping.
	[-locale=detect]   Locale.
	[-timezone=detect] Timezone.
	[-do_not_crypt_root_password]

Debug flags :
	[-keep_iso_copy]    Don't remove ISO copy.
	[-pause]
	[-emul]
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-do_not_crypt_root_password)
			crypt_root_password=no
			shift
			;;

		-keymap=*)
			keymap=${1##*=}
			shift
			;;

		-locale=*)
			locale=${1##*=}
			shift
			;;

		-timezone=*)
			timezone=${1##*=}
			shift
			;;

		-keep_iso_copy)
			keep_iso_copy=yes
			shift
			;;

		-pause)
			PAUSE=ON
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

ple_enable_log

exit_if_dir_not_exists $iso_olinux_path
exit_if_file_not_exists $master_ks_cfg

typeset -r	iso_name=${full_linux_iso_name##*/}
typeset	-r	iso_copy=COPY_OF_${iso_name}
typeset	-r	ks_cfg="$iso_olinux_path/ks.cfg"

#	Copie le contenu de l'ISO dans $1
function copy_iso_2_dir
{
	typeset -r	dest=$1

	if [ -d $dest ]
	then
		info "directory '$dest' exist, copy skipped."
		LN
		return 0
	fi

	#	Working Mount Point
	typeset -r	working_mp=/tmp/loop_device

	line_separator
	info "Mount ${iso_name} on $working_mp"
	[ ! -d $working_mp ] && exec_cmd mkdir $working_mp
	exec_cmd sudo mount -o loop -t iso9660 $full_linux_iso_name $working_mp
	LN

	line_separator
	info "Copy ${iso_name} to directory $dest/"
	exec_cmd mkdir $dest
	exec_cmd cp -pRf $working_mp/* $dest/
	LN

	line_separator
	info "Remove mount point : $working_mp"
	exec_cmd "sudo umount $working_mp"
	exec_cmd "rmdir $working_mp"
	LN
}

#	$1 : répertoire contenant l'ISO dupliqué.
#	copie le ficher kickstat mis à jour.
function copy_ks_file
{
	typeset -r	dest=$1

	line_separator
	info "Copy kickstart file"
	exec_cmd "cp $ks_cfg $dest/ks.cfg"
	LN
}

#	$1 : répertoire contenant l'ISO dupliqué.
#	Le fichier kickstart sera chargé au boot.
function update_isolinux_cfg
{
	typeset -r	isolinux_cfg=$1/isolinux/isolinux.cfg

	line_separator
	info "Update isolinux.cfg to load kickstart file."
	exec_cmd "sed -i 's,quiet,ks=cdrom:/ks.cfg quiet,g' $isolinux_cfg"
	LN

	info "set timout 1"
	sed -i "s/timeout 600/timeout 1/" $isolinux_cfg
	LN

	info "Change default menu"
	sed -i "/menu default/d" $isolinux_cfg
	sed -i "/  menu label ^Install Oracle Linux $OL7_LABEL/a \ \ menu default" $isolinux_cfg
	LN
}

function setup_ks_file
{
	info "Configure kickstart file."

	info -n "Define root password for VM (Press enter for : R00T_P@SSW0RD) : "
	read root_password
	if [ x"$root_password" == x ]
	then
		root_password="R00T_P@SSW0RD"
		info "Root password will be : ${BOLD}${root_password}${NORM}"
	fi
	LN

	#	Le fichier de référence $master_ks_cfg et copié au niveu de l'ISO sous le
	#	nom de $ks_cfs. C'est le fichier $ks_cfg qui est customisé.
	exec_cmd "cp $master_ks_cfg $ks_cfg"
	LN

	info "Update kickstart file :"
	LN

	info " * update keymap to $keymap"
	exec_cmd "sed -i \"s/^keyboard --vckeymap=.*$/keyboard --vckeymap=${keymap}-oss --xlayouts='${keymap} (oss)'/\" $ks_cfg"
	LN

	info " * update lang to $locale"
	exec_cmd "sed -i \"s/^lang.*$/lang $locale/\" $ks_cfg"
	LN

	#	L'objectif est que l'utilisateur ne clic par partout et fasse planter
	#	l'installation en pensant qu'il doivent saisir dès informations.
	info "Cmdline install"
	exec_cmd "sed -i 's/graphical/cmdline/g' $ks_cfg"
	LN

	info " * update root password"
	if [ $crypt_root_password == yes ]
	then
		python_cmd="import crypt; print crypt.crypt( \"$root_password\", '\$6\$saltsalt\$' )"
		pass=$(echo "$python_cmd" | python -)
		root_password_crypted=$(escape_slash $pass)
		exec_cmd "sed -i 's/^rootpw.*$/rootpw --iscrypted $root_password_crypted/' $ks_cfg"
	else
		exec_cmd "sed -i 's/^rootpw.*$/rootpw $root_password/' $ks_cfg"
	fi
	LN

	info " * update timezone to $timezone"
	exec_cmd "sed -i \"s,^timezone.*$,timezone $timezone --isUtc,\" $ks_cfg"
	LN

	info "Update network"
	typeset -r mask=$(convert_net_prefix_2_net_mask $if_pub_prefix)
	exec_cmd "sed -i \"s/network  --bootproto=static .*/network  --bootproto=static --device=$if_pub_name --ip=$master_ip --netmask=${mask} --ipv6=auto --activate/\" $ks_cfg"
	LN
	exec_cmd "sed -i \"s/network  --hostname=.*/network  --hostname=${master_hostname}.${infra_domain}/\" $ks_cfg"
	LN
}

#	L'auto détection fonctionne sur mon poste, j'attends la confirmation qu'elle
#	fonctionne ailleurs.
typeset confirm_detect=no

if [ "$keymap" == detect ]
then
	keymap=$(LANC=C localectl | grep "VC Keymap" | awk '{ print $3 }')
	confirm_detect=yes
fi

if [ "$locale" == detect ]
then
	locale=$LANG
	confirm_detect=yes
fi

if [ "$timezone" == detect ]
then # Le label peut être 'Timezone' ou 'Time zone' celon la distribution.
	timezone=$(LANC=C timedatectl | grep -E "Time\s{0,1}zone" | cut -d: -f2 | awk '{ print $1 }')
	if [[ "$timezone" == "n/a" || x"$timezone" == x ]]
	then
		exec_cmd timedatectl
		LN

		error "Cannot detect your timezone, use parameter -timezone=\"your timezone\""
		LN
		exit 1
	fi
	confirm_detect=yes
fi

if [ $confirm_detect == yes ]
then # Au moins un paramètre a été détecté, il faut confirmer.
	line_separator
	info "Keymap    = $keymap"
	info "Locale    = $locale"
	info "Time zone = $timezone"
	LN
	confirm_or_exit "Loaded settings from your configuration are correct :"
fi

line_separator
exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc 2>&1"
if [ $? -ne 0 ]
then
	cat /tmp/vc
	rm -f /tmp/vc
	exit 1
fi
rm -f /tmp/vc

line_separator
setup_ks_file
LANG=C

if [ ! -d $iso_ks_olinux_path ]
then
	line_separator
	info "Create directory : $iso_ks_olinux_path"
	exec_cmd "mkdir $iso_ks_olinux_path"
	LN
fi

line_separator
fake_exec_cmd cd $iso_ks_olinux_path
cd $iso_ks_olinux_path
LN

copy_iso_2_dir ./$iso_copy

copy_ks_file ./$iso_copy

update_isolinux_cfg ./$iso_copy

test_pause "Setup ISO copy done."

info "Create bootable ISO ${iso_name} from $iso_copy"
add_dynamic_cmd_param "-quiet"
add_dynamic_cmd_param "-r -V \"OL-$OL7_LABEL Server.x86_64\" -cache-inodes -J -l"
add_dynamic_cmd_param '-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot'
add_dynamic_cmd_param "-boot-load-size 4 -boot-info-table -o ${iso_name} $iso_copy/"
exec_dynamic_cmd "sudo genisoimage"
LN

line_separator
if [ $keep_iso_copy == no ]
then
	info "Remove : $iso_copy"
	exec_cmd "sudo rm -rf $iso_copy"
	LN
else
	info "Keep directory : $iso_copy"
	LN
fi

line_separator
info "ISO $iso_ks_olinux_path/${iso_name} [$OK]"
LN

info "Execute : ./01_create_vm_and_install_ol7.sh"
LN
