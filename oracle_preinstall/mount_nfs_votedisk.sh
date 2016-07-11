#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

#	Sur le serveur qui exporte :
#	Le fichier /etc/exports contient :
#	/votedisks linraaa0*(rw,sync,all_squash,anonuid=1100,anongid=1000,no_subtree_check)
#
#	Relancer par exportfs -r


exec_cmd -cont mkdir /votedisks

echo "linarc:/votedisks /votedisks nfs rw,bg,hard,intr,rsize=32768,wsize=32768,tcp,noac,vers=3,timeo=600" >> /etc/fstab

exec_cmd mount /votedisks

typeset -r hn=$(hostname -s)
typeset -r votename=${hn:0:${#hn}-2}

votedisk=/votedisks/$votename

if [ -f $votedisk ]
then
    echo "'$votedisk' exists no action"
else
    dd if=/dev/zero of=$votedisk bs=1M count=500
fi

