#!/bin/bash

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r str_usage=\
"Usage : $ME
	[-skip_iso_copy] N'effectue pas la copie de l'image ISO (elle est donc déjà faite)
	[-pause]         Active les points de debuggage.
	[-emul]

Note : ne fonctionne pas correctement, l'image créer ne boot pas mais je ne sais
pas pourquoi.
"

typeset	skip_iso_copy=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-skip_iso_copy)
			skip_iso_copy=yes
			shift
			;;

		-pause)
			PAUSE=ON
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
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

LANG=C

exit_if_dir_not_exists $iso_olinux_path
exit_if_file_not_exists $iso_olinux_path/master-ks.cfg

typeset -r iso_name=${full_linux_iso_name##*/}
typeset -r ISO_DEST=$iso_olinux_path/KS_ISO

function copy_iso_2_dir	# $1 destination
{
	typeset -r	dest=$1

	#	Working Mount Point
	typeset -r	working_mp=/tmp/mnt

	line_separator
	info "Mount ${iso_name} on $working_mp"
	[ ! -d $working_mp ] && exec_cmd mkdir $working_mp
	exec_cmd sudo mount -o loop -t iso9660 $full_linux_iso_name $working_mp
	LN

	line_separator
	info "Copy ${iso_name} to directory $dest/"
	exec_cmd mkdir $dest
	exec_cmd cp -pr $working_mp/* $dest/
	LN

	line_separator
	info "Supprime le point de montage $working_mp"
	exec_cmd "sudo umount $working_mp"
	exec_cmd "rmdir $working_mp"
	LN
}

function copy_ks_file	#	$1 dest
{
	typeset -r	dest=$1

	line_separator
	info "Copy $iso_olinux_path/master-ks.cfg $dest/ks.cfg"
	exec_cmd "cp $iso_olinux_path/master-ks.cfg $dest/ks.cfg"
	LN
}

line_separator
fake_exec_cmd cd $iso_olinux_path
cd $iso_olinux_path
LN

if [ ! -d $ISO_DEST ]
then
	if [ $skip_iso_copy == yes ]
	then
		error "La copie n'existe pas : '$ISO_DEST'"
		exit 1
	fi

	info "Create directory : $ISO_DEST"
	exec_cmd "mkdir $ISO_DEST"
	LN
elif [ $skip_iso_copy == no ]
then
	info "Remove all files from $ISO_DEST"
	exec_cmd "sudo rm -rf $ISO_DEST/*"
	LN
fi

line_separator
fake_exec_cmd cd $ISO_DEST
cd $ISO_DEST
LN

if [ $skip_iso_copy == no ]
then
	copy_iso_2_dir ./COPY_OF_${iso_name}
	copy_ks_file ./COPY_OF_${iso_name}

	test_pause "Vérifier si la copie est ok !"
fi

info "pwd = $PWD"
LN

info "Create bootable ISO ${iso_name} from COPY_OF_${iso_name}"
add_dynamic_cmd_param '-r -V "ISO-LABEL" -cache-inodes -J -l'
add_dynamic_cmd_param '-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot'
add_dynamic_cmd_param "-boot-load-size 4 -boot-info-table -o ${iso_name} COPY_OF_${iso_name}/"
exec_dynamic_cmd "sudo genisoimage"
LN

line_separator
info "Remove COPY_OF_${iso_name}"
exec_cmd "sudo rm -rf COPY_OF_${iso_name}"
LN

line_separator
info "ISO $ISO_DEST/${iso_name} [$OK]"
LN
