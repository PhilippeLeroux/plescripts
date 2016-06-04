#/bin/sh

typeset -r mem_node=/tmp/mem_node

if [ -f $mem_node ]
then
	node=$(cat $mem_node)
	ping -c 1 $node 1>/dev/null
	if [ $? -eq 0 ]
	then
		echo $node
		exit 0
	fi

	rm -f $mem_node
fi

node=rac${1}01
ping -c 1 $node 1>/dev/null
if [ $? -ne 0 ]
then
	node=rac${1}02
	ping -c 1 $node 1>/dev/null
	[ $? -ne 0 ] && exit 1
fi

echo $node > $mem_node
echo $node
exit 0
