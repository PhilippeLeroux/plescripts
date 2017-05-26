### Gestion du DNS

Les scripts doivent être exécutés depuis le serveur K2 dans le répertoire ~/plescripts/dns
et avec le compte root.

__Ajout/suppression de serveurs :__

*	Visualiser tous les serveurs enregistrés dans le DNS : `./show_dns.sh`

*	Ajouter un serveur : `./add_server_2_dns.sh -name=srvtchourie01 -ip_node=110`

*	Supprimer toutes les IPs d'un serveur, ex :`./remove_db_from_dns.sh -db=tchourie`

*	Supprime un serveur du DNS : `./remove_server.sh -name=srvtchourie01`

--------------------------------------------------------------------------------

__Scripts utilisés par les scripts présents dans plescripts/database_server :__

*	get_free_ip_node.sh
	Permet d'obtenir la première IP libre, ou un intervalle d'IPs libre.

	Exemple `./get_free_ip_node.sh -range=4` l'IP retournée est libre ainsi que
	les 3 suivantes.

*	test_ip_node_used.sh
	Retourne 0 si l'IP passée en paramètre est utilisée, 1 sinon.
