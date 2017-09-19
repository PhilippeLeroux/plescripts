# vim: ts=4:sw=4

# $1 vm name
# return 0 if running, else 1
function vm_running
{
	grep -q "$1"<<<"$(VBoxManage list runningvms)"
}
