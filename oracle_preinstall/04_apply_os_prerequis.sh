#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db_type=single|rac|single_fs"

typeset db_type=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		-db_type=*)
			db_type=${1##*=}
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

exit_if_param_invalid db_type "single rac single_fs"	"$str_usage"

# $1 size in Kb
function fmt_kb2mb
{
	typeset -ri kb=$1
	echo "$(fmt_number $(to_mb ${kb}K) )Mb"
}

function set_limit
{
	typeset -r domain=$1
	typeset -r type=$2
	typeset -r item=$3
	typeset -r value=$4

	exec_cmd "sed -i \"/^$domain\s\{1,\}$type\s\{1,\}$item\s.*$/d\" /etc/security/limits.conf"
	exec_cmd "printf \"%-8s %-6s %-8s %10s\n\" $domain $type $item $value >> /etc/security/limits.conf"
}

function memory_setting
{
	typeset -ri	ram_kb=$(memory_total_kb)
	typeset -ri percent=$oracle_grid_mem_lock_pct
	typeset -ri	mem_limit=$(echo "($percent*$ram_kb)/100" | bc)

	info "RAM                             : $(fmt_kb2mb $ram_kb)"
	info "locked address space for oracle : $(fmt_kb2mb $mem_limit) (${percent}% of $(fmt_kb2mb $ram_kb))"
	info "locked address space for grid   : $(fmt_kb2mb $mem_limit) (${percent}% of $(fmt_kb2mb $ram_kb))"
	LN

	info "Met à jour les limites mémoire."
	LN

	set_limit oracle soft memlock $mem_limit
	LN

	set_limit oracle hard memlock $mem_limit
	LN

	[ $db_type == single_fs ] && return 0 || true

	set_limit grid soft memlock $mem_limit
	LN

	set_limit grid hard memlock $mem_limit
	LN

	info "Divers :"
	LN

	set_limit grid hard nproc  16384
	LN

	set_limit grid hard nofile 65536
	LN

	# 12.2
	set_limit grid soft stack 10240
	LN
}

function dev_shm_setting
{
	info "mount /dev/shm on startup"

	exec_cmd "sed -i \"/^.*\/dev\/shm.*/d\" /etc/fstab"

	case "$max_shm_size" in
		config)
			if [ $db_type == single_fs ]
			then	# En mode fs on laisse le défaut.
				exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults 0 0\" >> /etc/fstab"
			else
				[ $db_type == single ] && shm_size=$min_shm_size_single || shm_size=$min_shm_size_rac
				exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults,size=$shm_size 0 0\" >> /etc/fstab"
			fi
			LN
			;;

		auto)
			exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults 0 0\" >> /etc/fstab"
			LN
			;;

		*)
			error "max_shm_size='$max_shm_size' invalid."
			exit 1
			;;
	esac
}

function create_tuned_profiles
{
	exec_cmd "~/plescripts/oracle_preinstall/create_tuned_profiles.sh"
}

function setup_ssh_config
{
	exec_cmd "sed -i 's/.*LoginGraceTime.*/LoginGraceTime 0/' /etc/ssh/sshd_config"
}

line_separator
memory_setting
LN

line_separator
create_tuned_profiles
LN

line_separator
dev_shm_setting
LN

line_separator
setup_ssh_config
LN
