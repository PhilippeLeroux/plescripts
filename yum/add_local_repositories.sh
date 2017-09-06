#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -role=master|infra
Créé les dépôts locaux yum. Les dépôts sont hébergés par $infra_hostname.
	-role=master sur le serveur $master_hostname, ou sur un serveur de BDD.
	-role=infra sur le serveur $infra_hostname.
" 

typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-role=*)
			role=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_invalid role "master infra" "$str_usage"

#	Supprime le ss-répertoire x86_64
if [ $role == master ]
then
	typeset	-r url_is="file:///mnt${infra_olinux_repository_path}"
else
	typeset	-r url_is="file://${infra_olinux_repository_path}"
fi

typeset	-r	repo_file=/etc/yum.repos.d/public-yum-ol7.repo

if [ ! -f ${repo_file}.original ]
then
	info "Backup de $repo_file"
	exec_cmd "cp $repo_file ${repo_file}.original"
fi

typeset	-i	first_line=$(grep -n local_ol7_latest $repo_file| cut -d: -f1)
if [ $first_line -ne 0 ]
then	# supprimme les dépôts locaux :
	((--first_line)) # Pour supprimer la ligne vide.
	info "Truncate repo file at line : $first_line"
	exec_cmd "sed -i '${first_line},\$d' $repo_file"
	LN
fi

# Test si le dépôt R4 est renseigné.
if ! grep -q ol7_UEKR4 $repo_file
then
	info "Add repository ol7_UEKR4"
	cat<<-EOC>>$repo_file

	[ol7_UEKR4]
	name=Latest Unbreakable Enterprise Kernel Release 4 for Oracle Linux \$releasever (\$basearch)
	baseurl=http://public-yum.oracle.com/repo/OracleLinux/OL7/UEKR4/\$basearch/
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
	gpgcheck=1
	enabled=0
	EOC
	LN

	info "Yum repository updated."
	LN
fi

info "Add repositories local_ol7_latest, R3, R4 DVD_R2 && DVD_R3 && DVD_R4"
cat <<EOC >>$repo_file

[local_ol7_latest]
name=Oracle Linux \$releasever Latest (\$basearch)
baseurl=$url_is/ol7_latest/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0

[ol7_DVD_R2]
name=DVD Unbreakable Enterprise Kernel Release 2 for Oracle Linux \$releasever (\$basearch)
baseurl=$url_is/DVD_R2/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0

[ol7_DVD_R3]
name=DVD Unbreakable Enterprise Kernel Release 3 for Oracle Linux \$releasever (\$basearch)
baseurl=$url_is/DVD_R3/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0

[ol7_DVD_R4]
name=DVD Unbreakable Enterprise Kernel Release 4 for Oracle Linux \$releasever (\$basearch)
baseurl=$url_is/DVD_R4/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0

[local_ol7_UEKR3]
name=Latest Unbreakable Enterprise Kernel Release 3 for Oracle Linux \$releasever (\$basearch)
baseurl=$url_is/ol7_UEKR3/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0

[local_ol7_UEKR4]
name=Latest Unbreakable Enterprise Kernel Release 4 for Oracle Linux \$releasever (\$basearch)
baseurl=$url_is/ol7_UEKR4/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=0
EOC
LN

info "Yum repository updated."
LN
