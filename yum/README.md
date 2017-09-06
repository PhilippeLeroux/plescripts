* Pour mémoire

	Créer une VM à partir du DVD R2, puis mis à jour en R3 entraîne des
	dysfonctionnements Par exemple avec Oracle 12.1 le tunnel ssh ne fonctionne
	plus et `runInstaller` demande d'exporter le `DISPLAY`.
	Avec Oracle 12cR2 le link du Grid Infra échoue systématiquement, il y a pas
	mal	d'autres soucis du genre.

	Donc il est plus fiable de créer un VM à partir du DVD R3, puis de faire la
	mise à jour.

	Note : Avec la R3 les fichiers des bases sont souvent corrompues, pour le
	moment il est préférable de faire gérer les disques par VBox.

	Pour tester OL7 en R4, il faudra donc créer la VM avec le DVD R4.

* Dépôts par défaut

	Le dépôt R3 est activé sur tous les serveurs.

	Fonctionnement dès dépôts :
	* Le répertoire commun à tous les dépôts est : /repo/OracleLinux
	* Chaque dépôt a un ss-répertoire dans : /repo/OracleLinux
	* Le createrepo doit se faire sur chaque ss-répertoire et non pas sur le
	répertoire /repo/OracleLinux

* Description des dépôts OL7

	[Documentation](https://docs.oracle.com/cd/E52668_01/E60259/html/ol7-install.html)

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
	gmain       723  737           root  DEL       REG              252,0             33674513 /usr/lib64/libnspr4.so
	gmain       723  737           root  DEL       REG              252,0             33674515 /usr/lib64/libplc4.so
	gmain       723  737           root  DEL       REG              252,0             33674535 /usr/lib64/libplds4.so
	gmain       723  737           root  DEL       REG              252,0             33674536 /usr/lib64/libnssutil3.so
	gmain       723  737           root  DEL       REG              252,0             33806706 /usr/lib64/libnss3.so
	gmain       723  737           root  DEL       REG              252,0             33806657 /usr/lib64/libsmime3.so
	gmain       723  737           root  DEL       REG              252,0             33806783 /usr/lib64/libssl3.so
	gmain       723  737           root  DEL       REG              252,0             33793069 /usr/lib64/libudev.so.1.6.2
	gmain       723  737           root  DEL       REG              252,0             33793067 /usr/lib64/libsystemd.so.0.6.0
	gmain       723  737           root  DEL       REG              252,0             34081792 /usr/lib64/libgudev-1.0.so.0.2.0
	gdbus       723  739           root  DEL       REG              252,0            101038986 /usr/lib64/NetworkManager/libnm-device-plugin-team.so;58c29691
	gdbus       723  739           root  DEL       REG              252,0            101302725 /usr/lib64/NetworkManager/libnm-settings-plugin-ibft.so;58c29691
	gdbus       723  739           root  DEL       REG              252,0            100862066 /usr/lib64/NetworkManager/libnm-settings-plugin-ifcfg-rh.so;58c29691
	gdbus       723  739           root  DEL       REG              252,0             33674538 /usr/lib64/libaudit.so.1.0.0
	gdbus       723  739           root  DEL       REG              252,0             33674513 /usr/lib64/libnspr4.so
	gdbus       723  739           root  DEL       REG              252,0             33674515 /usr/lib64/libplc4.so
	gdbus       723  739           root  DEL       REG              252,0             33674535 /usr/lib64/libplds4.so
	gdbus       723  739           root  DEL       REG              252,0             33674536 /usr/lib64/libnssutil3.so
	gdbus       723  739           root  DEL       REG              252,0             33806706 /usr/lib64/libnss3.so
	gdbus       723  739           root  DEL       REG              252,0             33806657 /usr/lib64/libsmime3.so
	gdbus       723  739           root  DEL       REG              252,0             33806783 /usr/lib64/libssl3.so
	gdbus       723  739           root  DEL       REG              252,0             33793069 /usr/lib64/libudev.so.1.6.2
	gdbus       723  739           root  DEL       REG              252,0             33793067 /usr/lib64/libsystemd.so.0.6.0
	gdbus       723  739           root  DEL       REG              252,0             34081792 /usr/lib64/libgudev-1.0.so.0.2.0
	in:imjour  1056 1076           root  DEL       REG              252,0             33793067 /usr/lib64/libsystemd.so.0.6.0
	rs:main    1056 1077           root  DEL       REG              252,0             33793067 /usr/lib64/libsystemd.so.0.6.0
	```
* sync_oracle_repository.sh

	Ne doit être exécuté que sur le serveur d'infra.

	Synchronise le dépôt local ol7 avec le dépôt internet.

	Avec le paramètre -use_tar=name.tar.gz, extrait le dépôt contenu dans l'archive.

	Teste si des mises à jour sont disponibles, si oui synchronise le dépôt et
	met à jour le serveur.

	Tous les serveurs du réseau virtuelle utilise le dépôt du serveur d'infra
	pour se mettre à jour.

* init_infra_repository.sh

	Doit être exécuté sur le virtual-host.

	Clone le dépôt OL7 sur K2, ou restaure la sauvegarde locale.

* backup_infra_repository.sh

	Doit être exécuté sur le virtual-host.

	Sauvegarde le dépôt OL7 du serveur K2 en locale.
