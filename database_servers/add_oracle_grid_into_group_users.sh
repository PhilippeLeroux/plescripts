#/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd -c "usermod -a -G users grid"
if [ $? -ne 0 ]
then
	info "No error database without grid."
	LN
fi
exec_cmd "usermod -a -G users oracle"
LN
