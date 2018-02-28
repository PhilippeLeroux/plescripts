* Pour mémoire

	Créer une VM à partir du DVD R2, puis mis à jour en R3 entraîne des
	dysfonctionnements Par exemple avec Oracle 12.1 le tunnel ssh ne fonctionne
	plus et `runInstaller` demande d'exporter le `DISPLAY`.
	Avec Oracle 12cR2 le link du Grid Infra échoue systématiquement, il y a pas
	mal	d'autres soucis du genre.

	Donc il est plus fiable de créer un VM à partir du DVD correspondant à la
	version d'OL7 que l'on souhaite.

* Dépôts par défaut

	Le répertoire commun à tous les dépôts est : `/repo/OracleLinux`

	Sur les VMs bdd le dépôt est accessible sur : `/mnt/repo/OracleLinux`

* Description des dépôts OL7

	[Documentation](https://docs.oracle.com/cd/E52668_01/E60259/html/ol7-install.html)

* sync_oracle_repository.sh

	Ne doit être exécuté que sur le serveur d'infra.

	Synchronise le dépôt local ol7 avec le dépôt internet.

	Avec le paramètre -use_tar=name.tar.gz, extrait le dépôt contenu dans l'archive.

* Tester si un reboot est nécessaire après un `yum update`

	Si la commande `lsof | awk '$5 == "DEL" { print }'` affiche des lignes il faut
	rebooter.

	Si le kernel est mis à jour, ce n'est pas visible par cette méthode, il faut
	rebooter.

	```
	[root@srvdaisy01 ~]# lsof | awk '$5 == "DEL" { print }'
	gmain       723  737           root  DEL       REG              252,0            101038986 /usr/lib64/NetworkManager/libnm-device-plugin-team.so;58c29691
	gmain       723  737           root  DEL       REG              252,0            101302725 /usr/lib64/NetworkManager/libnm-settings-plugin-ibft.so;58c29691
	gmain       723  737           root  DEL       REG              252,0            100862066 /usr/lib64/NetworkManager/libnm-settings-plugin-ifcfg-rh.so;58c29691
	gmain       723  737           root  DEL       REG              252,0             33674538 /usr/lib64/libaudit.so.1.0.0
	[ output skipped ]
	```

* init_infra_repository.sh

	Doit être exécuté sur le virtual-host.

	Clone le dépôt OL7 sur K2, ou restaure la sauvegarde locale.

* backup_infra_repository.sh

	Doit être exécuté sur le virtual-host.

	Sauvegarde le dépôt OL7 du serveur K2 en locale.
