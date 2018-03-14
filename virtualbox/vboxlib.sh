# vim: ts=4:sw=4

# $1 vm name
# return 0 if vm running, else 1
function vm_running
{
	grep -qE "\<$1\>"<<<"$(VBoxManage list runningvms)"
}

# $1 vm name
# return 0 if vm exists, else 1
function vm_exists
{
	grep -q "$1"<<<"$(VBoxManage list vms)"
}

# $1 vm name
# print to stdout memory size
function vm_memory_size
{
	VBoxManage showvminfo $1 | grep -E "^Memory size:" | awk '{ print $3 }'
}
