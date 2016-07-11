#!/bin/ksh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

typeset		batch_mode=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset -ri hpage_size_mb=$(to_mb $(get_hugepages_size_kb)K)

typeset -i shm_size_mb=-1
typeset -i shm_used_mb=-1

read fs shm_size_mb shm_used_mb rem<<<"$(df -m /dev/shm | tail -1)"
typeset -ri actual_hpages=$(sysctl -n vm.nr_hugepages)
typeset -ri shm_hpage_mb=$(compute -i "$actual_hpages * $hpage_size_mb")

info "Shm size          : $(fmt_number $shm_size_mb)Mb"
info "Shm used          : $(fmt_number $shm_used_mb)Mb"
info "Hpage size        : $(fmt_number $hpage_size_mb)Mb"
info "Hpages configured : $(fmt_number $actual_hpages) = $(fmt_number $shm_hpage_mb)Mb"
LN

typeset -i need_hpages_for_all=$(compute -i "$shm_size_mb / $hpage_size_mb")
typeset -i need_hpages_for_used=$(compute -i "$shm_used_mb / $hpage_size_mb")

typeset -i new_shm_size_mb=$(compute -i "$need_hpages_for_all * $hpage_size_mb")
info "For shm size need : $(fmt_number $need_hpages_for_all) huge pages"
info "For shm used need : $(fmt_number $need_hpages_for_used) huge pages"
LN

typeset -i nr_hugepages=0
info -n "Number huge pages to set : "
read nr_hugepages

if [ $nr_hugepages -lt $need_hpages_for_used ] || [ $nr_hugepages -gt $need_hpages_for_all ]
then
	error "$nr_hugepages not in [$need_hpages_for_used,$need_hpages_for_all]"
	exit 1
fi
info "==> $nr_hugepages"

info "Memory configuration before adjustment :"
exec_cmd "free -m"
LN

info "Update hugepages configuration :"
update_value vm.nr_hugepages $nr_hugepages $sysctl_file
exec_cmd "sysctl -w vm.nr_hugepages=$nr_hugepages"
exec_cmd "sysctl vm.nr_hugepages"
LN

if [ $(sysctl -n vm.nr_hugepages) -ne $nr_hugepages ]
then
	warning "Reboot OS : systemctl reboot"
	LN
	exit 1
else
	info "Memory configuration after adjustment :"
	exec_cmd "free -m"
	LN
	exit 0
fi
