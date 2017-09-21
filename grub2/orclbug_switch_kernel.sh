#!/bin/sh

# Ce script est copié, lors de l'installation d'un RAC 12.2, dans le répertoire
# /root.
#
# A utiliser quand les répertoires NFS ne fonctionnent plus et que la commande
# systemctl --failure montre que beaucoup de modules n'ont pas pus démarrer.
#
# Fonctionnement :
#	Si le noyau Oracle est actif, alors le noyau Redhat est activé et le
#	service oracle-ohasd.service est désactivé.
#
#	Si le noyau Redhat est actif, alors le noyau Oracle est activé et les
#	instructions pour activer et démarrer le service oracle-ohasd.service sont
#	affichées.
#
# Si il y toujours une erreur, rebooter sur un noyau redhat :
#	- Supprimer le noyau UEK : yum remove kernel-uek....
#	- rebooter
#	- installer le noyau UEK
#	- reboot
# Ca devrait le faire.

function run
{
	echo "$*"
	eval "$*"
}

function reboot_server
{
	echo "reboot server $(hostname -s)"
	echo
	sleep 5
	run reboot
}

KERNEL=$(grubby --default-kernel|sed "s/^.*linuz-\(.*el7\(uek\)\{0,1\}\).*/\1/g")

typeset -r reinstall_kernel_uek=/root/reinstall_kernel_uek.sh

if grep -q el7uek<<<"$KERNEL"
then
	redhat_k=$(grubby --info=ALL|grep -E "^kernel"|grep -v "uek"|head -1|cut -d= -f2)

	echo "Oracle kernel $KERNEL enable :"
	echo "    switch to Redhat kernel: $redhat_k"
	echo

	echo "Enter to continue, Ctrl+C to abort"
	read
	echo

	echo "Disable service : oracle-ohasd.service"
	run systemctl disable oracle-ohasd.service
	echo

	echo "Stop service : oracle-ohasd.service (background)"
	# En background, car ca peut être long.
	systemctl stop oracle-ohasd.service &
	echo

	# Création du script pour ré installer le noyau

	echo "echo \"yum -y remove kernel-uek-$KERNEL\""	> $reinstall_kernel_uek
	echo "yum -y remove kernel-uek-$KERNEL"				>> $reinstall_kernel_uek
	echo "sleep 5"										>> $reinstall_kernel_uek
	echo "echo"											>> $reinstall_kernel_uek
	echo "echo \"yum -y install kernel-uek-$KERNEL\""	>> $reinstall_kernel_uek
	echo "yum -y install kernel-uek-$KERNEL"			>> $reinstall_kernel_uek
	echo "sleep 5"										>> $reinstall_kernel_uek

	run chmod u+x $reinstall_kernel_uek

	echo "Script $reinstall_kernel_uek created."
	echo

	# Active le noyau Redhat
	run grubby --set-default $redhat_k
	echo

	reboot_server
elif [ -f $reinstall_kernel_uek ]
then # 2ieme reboot : ré installe le noyau UEK
	echo "Execute $reinstall_kernel_uek y/n ?"
	read keyboard
	if [ "$keyboard" == y ]
	then
		run $reinstall_kernel_uek
		run rm $reinstall_kernel_uek
		echo

		echo "Enable service : oracle-ohasd.service"
		run systemctl enable oracle-ohasd.service
		echo

		reboot_server
		exit 0
	fi
else # Normalement le code ci dessous n'a plus à être exécuté.
	orcl_k=$(grubby --info=ALL|grep -E "kernel.*uek.*"|head -1|cut -d= -f2)

	echo "Redhat kernel $KERNEL enable :"
	echo "    switch to Oracle kernel: $orcl_k"
	echo

	echo "Enter to continue, Ctrl+C to abort"
	read
	echo

	echo "After reboot enable service oracle-ohasd.service :"
	echo "$ systemctl enable oracle-ohasd.service"
	echo "$ systemctl start oracle-ohasd.service"
	echo

	run grubby --set-default $orcl_k
	echo

	reboot_server
fi
