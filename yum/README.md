* Dépôts par défaut.

	Le dépôt R3 est activé sur tous les serveurs.

	Fonctionnement dès dépôts :
	* Le répertoire commun à tous les dépôts est : /repo/OracleLinux
	* Chaque dépôt a un ss-répertoire dans : /repo/OracleLinux
	* Le createrepo doit se faire sur chaque ss-répertoire et non pas sur le
	répertoire /repo/OracleLinux

* Description des dépôts OL7

	[Documentation](https://docs.oracle.com/cd/E52668_01/E60259/html/ol7-install.html)

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
