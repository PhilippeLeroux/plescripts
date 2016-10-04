#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

info "Running : $ME $*"

#	Pour supprimer les acls : setfacl -Rb ~/plescripts/

#	Normalement :
#	Les acls sont positionnées sur le poste client qui exporte ~/plescripts par NFS.
#	Si un fichier est créé sur un des serveurs utilisant l'export NFS alors il est
#	possible de le manipuler sans trop de problèmes depuis le poste d'export.
info "Positionne les acls sur ~/plescripts"
exec_cmd -c setfacl -R -d -m u:${common_user_name}:rwx,g:users:rwx,o::r-x ~/plescripts/
if [ $? -ne 0 ]
then
	info "Vérifier que l'utilisateur $common_user_name et le groupe users existent."
fi
LN
