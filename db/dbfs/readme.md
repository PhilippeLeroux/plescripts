###	Création d'un FS de type DBFS

[Documentation DBFS](http://docs.oracle.com/database/121/ADLOB/adlob_client.htm#ADLOB45997)

[Clusterware Administration](https://docs.oracle.com/database/121/CWADD/crschp.htm#CWADD91277)

* Nom du CDC : `BABAR`
* Nom de la PDB : `BABAR01`
* Nom du service : `pdbBABAR01_oci`
* Point de montage : `/mnt/babar01`

La PDB contiendra un FS nommé `staging_area` qui sera visible de l'OS depuis le
point de montage `/mnt/babar01`. Le point de montage sera monté automatiquement à
l'ouverture de la PDB et démonté à la fermeture de la base.

Pour ne pas avoir à saisir de mot de passe, 'Wallet Manager' est utilisé.

#### Création du FS `staging_area` dans la PDB

Avec le compte `oracle` exécuter le script `create_dbfs.sh` :

```
cd ~/plescripts/db/dbfs
./create_dbfs.sh -pdb_name=babar01 -load_data
```

Le flag `-load_data` copie le contenu du répertoire courant sur le FS `staging_area`,
ca permet de valider son bon fonctionnement.

Le FS créé se nomme `staging_area`, à ce stade son contenu n'est accessible qu'avec
la commande oracle `dbfs_client`, exemple :

```
oracle@srvbabar01:BABAR:dbfs> dbfs_client /@pdbBABAR01_oci --command ls dbfs:/staging_area/
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

Le fichier `~/babar01_dbfs.cfg` contient toutes les informations sur le compte
gérant le `DBFS` dans la base.
Ce fichier est utilisé par les autres scripts pour éviter de ressaisir les mêmes
informations.

#### Rendre visible le FS `staging_area` depuis l'OS

Avec le compte `root` exécuter le script `configure_fuse_and_dbfs_mount_point.sh` :

```
[root@srvbabar01 ~]# cd ~/plescripts/db/dbfs
[root@srvbabar01 dbfs]# ./configure_fuse_and_dbfs_mount_point.sh -service_name=pdbbabar01_oci
```

Le script créé le point de montage `/mnt/babar01` qui contiendra le FS `staging_area`
créé avec le script `oracle`.

**Notes :**
* Exécuter le script sur tous les nœuds d'un RAC ou d'un dataguard.
* Après l'exécution du script, il faut se déconnecter du compte `oracle` pour
exécuter la commande `mount /mnt/babar01` la configuration du compte étant
modifiée.

Une entrée est ajoutée dans `/etc/fstab` qui permet au compte Oracle de monter
et démonter le FS.
* fstab : `/sbin/mount.dbfs#/@pdbbabar01_oci /mnt/babar01 fuse wallet,rw,user,allow_other,direct_io,noauto,default 0 0`
* Monter le FS : `mount /mnt/babar01`
* Démonter le FS : `fusermount -u /mnt/babar01`

Actuellement l'option `automount` n'est pas supportée par `fuse`.

#### Monter automatiquement le FS au démarrage de la base

Le point de montage `/mnt/babar01` doit être démonté sur tous les nœuds sinon
le script échouera.

Avec le compte `grid` exécuter le script `create_crs_resource_for_dbfs.sh`

```
grid@srvbabar01:+ASM:~> cd plescripts/db/dbfs/
grid@srvbabar01:+ASM:dbfs> ./create_crs_resource_for_dbfs.sh -pdb_name=babar01
[...]
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
pdb.babar01.dbfs
               ONLINE  ONLINE       srvbabar01               STABLE
               ONLINE  ONLINE       srvbabar02               STABLE
--------------------------------------------------------------------------------
```

La ressource `pdb.babar01.dbfs` se base sur le script `~/mount-dbfs-babar01` pour
gérer le FS.

Avec des ressources de type locale il n'est pas possible de passer des paramètres
au script ou bien d'utiliser dès variables d'environnement. Le suffix `babar01`
permet donc au script de connaître le nom du point de montage.

Chaque PDB contenant un DBFS aura donc son script.

### Gestion du point de montage depuis le compte `oracle`

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


