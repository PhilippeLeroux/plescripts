* Dépôts par défaut.

	Pour le serveur d'infra il est impératif que seul le dépôt `latest` soit
	activer.

	Avec les dépôts `R3` ou `R4`, `target` fonctionne vraiment très mal et est
	inutilisable. Toutes les BDD seront corrompus.

	Je n'ai pas testé l'activation des dépôts `R3` ou `R4` uniquement pour les
	serveurs de BDD.

	Pour que le dépôt `R3` ou `R4` soit disponible pour les serveurs de BDD il
	faut les télécharger sur le serveur d'infra :
	```
	ssh root@K2
	cd ~/plescripts/yum
	./sync_oracle_repository.sh -release=R3
	```

	Ensuite se connecter sur le serveur de BDD :
	```
	cd ~/plescripts/yum
	switch_repo_to.sh -local -release=R3
	yum update -y
	```

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
