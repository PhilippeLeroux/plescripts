################################################################################
Resume 2016/09/14 :
~~~~~~~~~~~~~~~~~~~

# 4 publics functions
# 0 privates functions
# 0 undocumented functions

################################################################################
4 publics functions :
~~~~~~~~~~~~~~~~~~~~~

#*>	$@ contient une commande à exécuter.
#*>	La fonction n'exécute pas la commande elle :
#*>		- affiche le prompt SQL> suivi de la commande.
#*>		- affiche sur la seconde ligne la commande.
#*>
#*>	Le but étant de construire dans une fonction 'les_commandes' l'ensemble des
#*>	commandes à exécuter à l'aide de to_exec.
#*>	La fonction 'les_commandes' donnera la liste des commandes à la fonction sqlplus_cmd
function to_exec

#*>	Exécute les commandes "$@" avec sqlplus en sysdba
#*>	Affichage correct sur la sortie std et la log.
function sqlplus_cmd

#*>	Objectif de la fonction :
#*>	 Exécute une requête, seul son résultat est affiché, la sortie peut être 'parsée'
#*>	 Par exemple obtenir la liste de tous les PDBs d'un CDB.
#*>	N'inscrit rien dans la log.
function sqlplus_exec_query

#*>	Objectif de la fonction :
#*>	 Exécute une requête dont le but n'est que l'affichage d'un résultat.
#*>	Affiche la requête exécutée.
function sqlplus_print_query


################################################################################
0 undocumented functions :
~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
0 privates functions :
~~~~~~~~~~~~~~~~~~~~~~

