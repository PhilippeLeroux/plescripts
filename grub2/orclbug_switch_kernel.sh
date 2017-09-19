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

function reboot_server
{
	echo "reboot server $(hostname -s)"
	echo
	sleep 5
	reboot
}

KERNEL=$(grubby --default-kernel|sed "s/^.*linuz-\(.*el7\(uek\)\{0,1\}\).*/\1/g")

typeset -r remove_kernel_uek=/root/remove_kernel_uek.sh
typeset -r install_kernel_uek=/root/install_kernel_uek.sh

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
	systemctl disable oracle-ohasd.service
	echo

	# Création du script pour supprimer le noyau
	echo "yum -y remove kernel-uek-$KERNEL" > $remove_kernel_uek
	echo "sleep 5" >> $remove_kernel_uek
	chmod u+x $remove_kernel_uek
	echo "Script $remove_kernel_uek created."
	echo

	# Création du script pour installer le noyau
	echo "yum -y install kernel-uek-$KERNEL" > $install_kernel_uek
	echo "sleep 5" >> $install_kernel_uek
	chmod u+x $install_kernel_uek
	echo "Script $install_kernel_uek created."

	# Active le noyau Redhat
	echo "grubby --set-default $redhat_k"
	grubby --set-default $redhat_k
	echo

	reboot_server
else
	if [ -f $remove_kernel_uek ]
	then # 1er reboot : supprime le noyau UEK
		echo "Execute $remove_kernel_uek y/n ?"
		read keyboard
		if [ "$keyboard" == y ]
		then
			$remove_kernel_uek
			rm $remove_kernel_uek
			reboot_server
			exit 0
		fi
	elif [ -f $install_kernel_uek ]
	then # 2ieme reboot : ré installe le noyau UEK
		echo "Execute $install_kernel_uek y/n ?"
		read keyboard
		if [ "$keyboard" == y ]
		then
			$install_kernel_uek
			rm $install_kernel_uek
			echo "After reboot execute : systemctl enable oracle-ohasd.service"
			reboot_server
			exit 0
		fi
	fi

	# Normalement le code ci dessous n'a plus à être exécuté.
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

	echo "grubby --set-default $orcl_k"
	grubby --set-default $orcl_k
	echo

	reboot_server
fi
