
# vim: ts=4:sw=4

typeset -r	sysctl_file=/etc/sysctl.conf
typeset -r	proc_meminfo=/proc/meminfo

#*> Print to stdout huge page size in Kb
function get_hugepages_size_kb
{
	grep "Hugepagesize:" $proc_meminfo | tr -s [:space:] | cut -d' ' -f2
}

#*> Print to stdout total huge pages.
function get_hugepages_total
{
	grep "HugePages_Total:" $proc_meminfo | tr -s [:space:] | cut -d' ' -f2
}

#*> Print to stdout numbre huge pages frees.
function get_hugepages_free
{
	grep "HugePages_Free:" $proc_meminfo | tr -s [:space:] | cut -d' ' -f2
}

#*> Print to stdout number of huge pages needed for sga of size $1
#*> $1 must contains unit K or M or G
function count_hugepages_for_sga_of
{
	typeset -r sga=$1

	typeset -ri hpage_mb=$(to_mb $(get_hugepages_size_kb)K)
	typeset -ri sga_mb=$(to_mb $sga)
	# Il me semble qu'il y a toujours 1 page non utilisée, à vérifier à l'usage
	echo $(( ($sga_mb / $hpage_mb) + 1 ))
}

#*> Print to stdout total OS memory in Kb
function memory_total_kb
{
	grep "MemTotal:" $proc_meminfo | tr -s [:space:] | cut -d' ' -f2
}

#*> Print to stdout OS free memory in Kb
function memory_free_kb
{
	grep "MemFree:" $proc_meminfo | tr -s [:space:] | cut -d' ' -f2
}
