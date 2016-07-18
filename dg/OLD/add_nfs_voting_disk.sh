#!/bin/bash

#	ts=4 sw=4

typeset -r hn=$(hostname -s)
typeset -r votename=${hn:0:${#hn}-2}

votedisk=/votedisks/$votename

if [ -f $votedisk ]
then
	echo "'$votedisk' exists no action"
else
	dd if=/dev/zero of=$votedisk bs=1M count=500
fi


echo "Add disk to crs :"
echo "	alter system set asm_diskstring='ORCL:*,$votedisk' scope=spfile sid='*'"
echo "	srvctl stop asm -f; srcvtl start asm"
echo "	alter diskgroup crs add quorum disk '$votedisk' size 500M;"
echo "	alter diskgroup crs drop disk 'Rxx_LUN_yy';"

