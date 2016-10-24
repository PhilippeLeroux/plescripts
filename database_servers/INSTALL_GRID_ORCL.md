###	Pré requis.

La ou les VMs doivent avoir été créées, instructions [ici](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/CREATE_SERVERS.md)

**Note** : Tous les scripts sont exécutés depuis le poste client/serveur host.

###	Installation du grid.

* Se positionner dans le répertoire : `cd ~/plescripts/database_servers`

* Lancer l'installation du Grid Infra `./install_grid.sh -db=daisy`

Le grid est installé en standalone ou cluster en fonction de la configuration.
Les scripts root sont exécutés sur l'ensemble des nœuds.

Les 2 DGs DATA et FRA sont créées, pour un cluster il y a en plus le DG CRS

__Note__ pour consommer le minimum de ressources un certain nombre de hacks
sont fait, -no_hacks permet de ne pas les mettre en œuvres.

###	Installation d'Oracle

* Se positionner dans le répertoire : `cd ~/plescripts/database_servers`

* Lancer l'installation d'oracle : `./install_oracle.sh -db=daisy`

Oracle est installé en standalone ou cluster. Les scripts root sont exécutés
sur l'ensemble des nœuds.

###	Création d'une base

Instructions [ici](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)
