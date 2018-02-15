# vim: ts=4:sw=4

#*> Retourne la taille du disque $1 en bytes.
function disk_size_bytes
{
	LANG=C fdisk -l $1 | head -2 | tail -1 | sed 's/.*, \(.*\) bytes.*/\1/'
}

#*> Retourne le nombre de partitions pour le disque $1
function count_partition_for
{
	typeset -i count=$(ls -1 $1* | wc -l)-1
	echo $count
}

#*> Retourne l'uuid du disque $1
function get_uuid_disk
{
	blkid $1 | sed 's/.*UUID="\(.*\)" T.*/\1/'
}

# $1 disk or partition name
# print to stdout the label
function label_of
{
	blkid $1|sed 's/.*LABEL="\(.*\)" TYPE.*/\1/'
}

#*>	Retourne le type du disque $1 ou unused si le disque n'est pas utilisé.
function disk_type
{
	typeset t
	# utilise read sinon il y a un espace en fin de ligne, je ne comprends pas
	read t<<<"$(blkid $1 | sed 's/.*TYPE=\"\(.*\)\"/\1/')"
	[ x"$t" = x ] && echo "unused" || echo $t
}

#*> Met à zéro l'en-tête du disque $1
#*> Si la taille $2 n'est pas précisée seront mis à zéro les
#*> 1024*1024*100 premiers bytes.
function clear_device
{
	typeset -r	device=$1
	typeset	-i	size_bytes=$2

	if [ ! -b $device ]
	then
		error "clear_device : $device not a block device"
	else
		[ $# -eq 1 ] && size_bytes=$(( 1024*1024*100 ))
		info "clear device $device : $(fmt_bytes_2_better $size_bytes)"
		exec_cmd dd if=/dev/zero of=$device bs=$size_bytes count=1
	fi
}

#*> Ajoute une partition sur le disque $1
#*> La partition est créée sur tout le disque.
function add_partition_to
{
	typeset -r device=$1
	info "add partition to $device"
	fake_exec_cmd "fdisk $device n p 1"
	[ $? -ne 0 ] && return 0

LANG=C fdisk $device <<EOS >/dev/null
n
p
1


w
EOS
	#	fdisk ne retourne pas d'erreur
	[ ! -b ${device}1 ] && return 1 || return 0
}

#*>	Supprime la partition du disque $1
function delete_partition
{
	typeset -r device=$1
	fake_exec_cmd "fdisk $device d"
	[ $? -ne 0 ] && return 0

LANG=C fdisk $device <<EOS >/dev/null
d
w
EOS
}

#*>	Convertie la valeur en base 16 $1 en base 10
function hexa_2_deci
{
	typeset -r hex=$(to_upper $1)
	echo "ibase=16; $hex" | bc
}

#*> Retourne les minor# et major# du disque $1
#*>	Format de retour "minor# major#"
function read_minor_major
{
	typeset	minor
	typeset	major
	read minor major <<<$(stat -c '%t %T' $1)
	echo "$(hexa_2_deci $minor) $(hexa_2_deci $major)"
}

#*> Retourne le disque correspondant aux n° minor $1 et major $2
function get_disk_minor_major
{
	typeset -r os_disks_path=/dev

	typeset -ri	minor=$1
	typeset -ri major=$2

	typeset	-r	device_name=$(ls -l /dev | grep -E ".*disk +${minor}, +${major} .*" | tr -s [[:space:]] | cut -d' ' -f10)
	echo $os_disks_path/$device_name
}

#*> Retourne le nom du disque système utilisé par le disque oracleasm $1
function get_os_disk_used_by_oracleasm
{
	typeset -r	oracleasm_disk_name=$1

	typeset -r	oracle_disks_path=/dev/oracleasm/disks

	typeset		minor
	typeset		major
	read minor major<<<$(read_minor_major $oracle_disks_path/$oracleasm_disk_name)
	get_disk_minor_major $minor $major
}


#*>	return unused disks without partitions.
function get_unused_disks_without_partitions
{
	function read_all
	{
		typeset	device
		while read device
		do
			[ "$(disk_type $device)" == unused ] && echo $device
		done<<<"$(find /dev -regex "/dev/sd.*[^0-9]")" | sort
	}

	typeset	list=$(read_all)
	# En premier les devices sdX
	typeset	list2=$(grep -E "/dev/...$"<<<"$list")
	# puis les devices sdXX
	printf "$list2\n$(grep -E "/dev/....$"<<<"$list")"
}
