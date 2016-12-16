###	Création d'un FS de type DBFS

[Documentation Oracle 12cR1](http://docs.oracle.com/database/121/ADLOB/adlob_client.htm#ADLOB45997)

* Nom du CDC : BABAR
* Nom de la PDB : BABAR01
* Nom du service : pdbBABAR01_oci

Le PDB contiendra un FS nommé `staging_area` qui sera visible de l'OS depuis le
point de montage `/mnt/babar01` (`babar01` étant le nom de la PDB)

Le DBFS devra être démarré automatiquent avec la base.

#### Création du FS `DBFS`

Avec le compte `oracle` exécuter le script `create_dbfs.sh` :

```
cd ~/plescripts/db/dbfs
./create_dbfs.sh -pdb_name=babar01 -account_name=dbfsadm -account_password=dbfs \
-load_data
```

Le flag `-load_data` copie le contenu du répertoire courant, sert pour valider
le bon fonctionnement de `DBFS`.

Le mot de passe du compte est mémorisé dans le fichier `~/babar01_pass`, il sera utilisé
pour transmettre le mot de passe à `dbfs_client`.

Le FS créé se nomme `staging_area`, à ce stade son contenu n'est accessible qu'avec
la commande oracle `dbfs_client`, exemples :

```
oracle@srvbabar01:BABAR:dbfs> dbfs_client dbfsadm@pdbBABAR01_oci --command ls dbfs:/staging_area/ < babar01_pass
Password:
dbfs:/staging_area/create_crs_resource_for_dbfs.sh
dbfs:/staging_area/create_dbfs.sql
dbfs:/staging_area/create_user_dbfs.sql
dbfs:/staging_area/drop_all.sh
dbfs:/staging_area/drop_dbfs.sql
dbfs:/staging_area/readme.md
dbfs:/staging_area/automount_dbfs.sh
dbfs:/staging_area/configure_fuse_and_dbfs_mount_point.sh
dbfs:/staging_area/create_dbfs.sh

oracle@srvbabar01:BABAR:dbfs>
```

Ne pas ajouter `*` pour lister le répertoire, la syntaxe `dbfs:/staging_area/*`
ne fonctionne pas.

Le fichier `~/babar01_info` contiendra toutes les informations pour supprimer le
compte avec le script `drop_all.sh`

#### Rendre visible le FS `staging_area` depuis l'OS

Le but est de pouvoir accéder à `staging_area` depuis l'OS, pour notamment
pouvoir copier les fichiers à charger en base.

Avec le compte `root` exécuter le script `configure_fuse_and_dbfs_mount_point.sh` :

```
[root@srvbabar01 ~]# cd ~/plescripts/db/dbfs
[root@srvbabar01 dbfs]# ./configure_fuse_and_dbfs_mount_point.sh	\
-service_name=pdbbabar01_oci -dbfs_user=dbfsadm -dbfs_password=dbfs
```

Le script créé le point de montage `/mnt/babar01` qui contiendra le FS `staging_area`
créé avec le script `oracle`.

**Remarque** Après l'exécution du script, il faut se déconnecter du compte `oracle`
pour exécuter les commandes `mount` ou `automount_dbfs.sh` la configuration des
compte `oracle` et `grid` étant modifiée.

L'entrée dans `/etc/fstab` permet de monter le fs avec la commande `mount /mnt/babar01`
avec le compte `oracle`. Mais ce n'est pas pratique, il faut saisir le mot de
passe et la commande ne rend pas la main, il faut donc faire :
```
nohup mount /mnt/babar01 < ~/babar01_pass &
```

Le script `automount_dbfs.sh` permet de lancer la commande en nohup, exemple :
```
oracle@srvbabar01:BABAR:dbfs> ./automount_dbfs.sh babar01
# Running : ./automount_dbfs.sh babar01

nohup: redirecting stderr to stdout
oracle@srvbabar01:BABAR:dbfs> cd /mnt/babar01/staging_area/
oracle@srvbabar01:BABAR:staging_area> ll
total 21
-rwxr-xr-- 1 kangs users  481 Dec 16 19:49 automount_dbfs.sh
-rwxrwxr-- 1 kangs users 3691 Dec 16 19:49 configure_fuse_and_dbfs_mount_point.sh
-rwxr-xr-- 1 kangs users 3901 Dec 16 19:49 create_crs_resource_for_dbfs.sh
-rwxrwxr-- 1 kangs users 2973 Dec 16 19:49 create_dbfs.sh
-rw-r--r-- 1 kangs users   77 Dec 16 19:49 create_dbfs.sql
-rw-rw-r-- 1 kangs users  408 Dec 16 19:49 create_user_dbfs.sql
-rwxr-xr-- 1 kangs users 1003 Dec 16 19:49 drop_all.sh
-rw-r--r-- 1 kangs users   64 Dec 16 19:49 drop_dbfs.sql
-rw-rw-r-- 1 kangs users 6173 Dec 16 19:49 readme.md
```

Ce script sera utilisé par le service du `CRS` qui aura en charge de démarrer le
FS.

Les erreurs de ce script sont loggées dans le fichier `/home/oracle/automount_babar01.nohup`

Pour démonter le FS : `fusermount -u /mnt/babar01`

#### Monter automatiquement le FS au démarrage de la base

Avec le compte `grid` exécuter le script `create_crs_resource_for_dbfs.sh`
```
grid@srvbabar01:+ASM:~> cd plescripts/db/dbfs/
grid@srvbabar01:+ASM:dbfs> ./create_crs_resource_for_dbfs.sh -pdb_name=babar01
[...]
17h21> crsctl stat res srv01.pdbbabar01.dbfs -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
srv01.pdbbabar01.dbfs
      1        ONLINE  ONLINE       srvbabar01               STABLE
--------------------------------------------------------------------------------
```

Le contenu du répertoire est maintenant visible :

```
oracle@srvbabar01:BABAR:dbfs> ll /mnt/babar01/staging_area/
total 20
-rwxr-xr-- 1 kangs users  686 Dec 16 17:15 automount_dbfs.sh
-rwxr-xr-- 1 kangs users 3695 Dec 16 17:15 create_crs_resource_for_dbfs.sh
-rwxrwxr-- 1 kangs users 2909 Dec 16 17:15 create_dbfs.sh
-rw-r--r-- 1 kangs users   77 Dec 16 17:15 create_dbfs.sql
-rw-rw-r-- 1 kangs users  408 Dec 16 17:15 create_user_dbfs.sql
-rwxr-xr-- 1 kangs users  486 Dec 16 17:15 drop_all.sh
-rw-r--r-- 1 kangs users   64 Dec 16 17:15 drop_dbfs.sql
-rw-rw-r-- 1 kangs users 4266 Dec 16 17:15 readme.md
-rwxrwxr-- 1 kangs users 3590 Dec 16 17:15 configure_fuse_and_dbfs_mount_point.sh
-rw-rw-r-- 1 kangs users  841 Dec 16 17:15 todo.txt
```

### BUGS

* Il n'est plus possible d'arrêter le service de la PDB associée au FS, même
avec l'option `-force`

* L'arrêt de la base n'est possible qu'avec l'option `-force`

* Le service du DBFS ne démarre pas après un arrêt démarrage de la base.

En gros je dois potasser la gestion du service avec le `CRS` :(
