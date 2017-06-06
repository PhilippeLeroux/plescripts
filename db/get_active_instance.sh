#!/bin/bash
# vim: ts=4:sw=4

#	-f3-4 pour gérer le cas des RAC One Node ou Policy Managed.
instance=$(ps -ef |  grep [p]mon | grep -vE "MGMTDB|\+ASM" | cut -d_ -f3-4)
if [ x"$instance" != x ]
then
	echo "$instance"
	exit 0
fi

exit 1
