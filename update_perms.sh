#/bin/sh

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

info "owner & group"
exec_cmd -c "sudo find ~/plescripts/ -type f | xargs chown ${common_user_name}:users"
exec_cmd -c "sudo find ~/plescripts/ -type d | xargs chown ${common_user_name}:users"
LN

info "Les répertoires"
exec_cmd -c "sudo find ~/plescripts/ -type d | xargs chmod ug=rwx,o=rx"
LN

info "Les fichiers"
exec_cmd -c "sudo find ~/plescripts/ -type f | xargs chmod ug=rw,o=r"
LN

info "Les script"
exec_cmd -c "sudo find ~/plescripts/ -name \"*.sh\" | xargs chmod ug=rwx,o=r"
exec_cmd -c "sudo find ~/plescripts/virtualbox/ -type f | xargs chmod ug=rwx,o=r"
LN

info "Les lib"
exec_cmd -c "sudo find ~/plescripts/ -name \"*lib.sh\" | xargs chmod ug=rw,o=r"
LN

info "Répertoire shell"
exec_cmd -c "sudo find ~/plescripts/shell -type f -and ! -name \"*.txt\" | xargs chmod ug+x,o-x"
LN

info "Cas particulier de template_script.txt"
exec_cmd "sudo chmod ug=rwx,o=r ~/plescripts/template_script.txt"
LN

info "Les docs"
exec_cmd -c "sudo find ~/plescripts/docs -type f | xargs chmod -x"
