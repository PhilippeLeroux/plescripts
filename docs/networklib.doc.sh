################################################################################
Resume 2016/07/25 :
~~~~~~~~~~~~~~~~~~~

# 5 publics functions
# 1 privates functions
# 0 undocumented functions

################################################################################
5 publics functions :
~~~~~~~~~~~~~~~~~~~~~

#*> Retourne le chemin contenant les fichiers de configuration des
#*> interfaces réseaux.
function get_if_path

#*>	Retourne l'adresse mac de l'Iface $1
function get_if_hwaddr

#*> Retourne 0 si l'ip $1 existe sinon 1
function dns_test_if_ip_exist

#*> retourne l'IP de l'host $1, ou rien si l'IP n'est pas trouvée.
function get_ip_for_host

#*> Supprime du fichier ~/.ssh/know_host l'hôte $1
function remove_from_known_hosts


################################################################################
0 undocumented functions :
~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
1 privates functions :
~~~~~~~~~~~~~~~~~~~~~~

#*< Permet de nettoyer mon bordel.
function cleanup_know_host

