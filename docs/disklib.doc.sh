################################################################################
Resume 2016/06/04 :
~~~~~~~~~~~~~~~~~~~

# 12 publics functions
# 0 privates functions
# 0 undocumented functions

################################################################################
12 publics functions :
~~~~~~~~~~~~~~~~~~~~~~

#*> Retourne la taille du disque $1 en bytes.
function disk_size_bytes

#*> Retourne le nombre de partitions pour le disque $1
function count_partition_for

#*> Retourne l'uuid du disque $1
function get_uuid_disk

#*>	Retourne le type du disque $1 ou unused si le disque n'est pas utilisé.
function disk_type

#*> Retourne le nom de tous les disques iscsi.
function get_iscsi_disks

#*> Met à zéro l'en-tête du disque $1
#*> Si la taille $2 n'est pas précisée seront mis à zéro les
#*> 10 000 000 premiers bytes.
function clear_device

#*> Ajoute une partition sur le disque $1
#*> La partition est créée sur tout le disque.
function add_partition_to

#*>	Supprime la partition du disque $1
function delete_partition

#*>	Convertie la valeur en base 16 $1 en base 10
function hexa_2_deci

#*> Retourne les minor# et major# du disque $1
#*>	Format de retour "minor# major#"
function read_minor_major

#*> Retourne le disque correspondant aux n° minor $1 et major $2
function get_disk_minor_major

#*> Retourne le nom du disque système utilisé par le disque oracleasm $1
function get_os_disk_used_by_oracleasm


################################################################################
0 undocumented functions :
~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
0 privates functions :
~~~~~~~~~~~~~~~~~~~~~~

