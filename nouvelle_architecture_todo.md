# Etude d'impacte :

## global.cfg
	if_net_name
		passer de eth2 à eth3

	if_priv_name :
		renomer en if_iscsi_name
		conserver eth1
		réseau 10.10.10/24

	if_rac_name (nouvelle interface) :
		vaut eth2
		réseau 20.20.20/24

## Impactes :

	1. Renommer if_priv_name en if_iscsi_name
	git mettra en évidence l'ensemble des fichiers/scripts impactées.

	2. Changer le réseau de if_iscsi_name ==> global.cfg uniquement

	A ce stade l'interco des disques est opérationnel et pas de scripts à adapter.
	(Confiance de 99.999999999999%)

	3. Scripts à modifier
		3.1 Le script `install_grid.sh` est à modifier.
			Remplacer tous les if_priv_name par if_rac_name.

		3.2 Les scripts de création de VMs
			Ce sont peut-être eux les plus hard.
			Demain je regarge en détails.
