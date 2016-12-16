###	Création d'un FS de type DBFS

[Documentation Oracle 12cR1](http://docs.oracle.com/database/121/ADLOB/adlob_client.htm#ADLOB45997)

* Nom du CDC : BIMBO
* Nom de la PDB : BIMBO01
* Nom du service : pdbBIMBO01_oci

#### Création du FS `DBFS`

Avec le compte `oracle` exécuter le script `create_dbfs.sh` :

```
cd ~/plescripts/db/dbfs
./create_dbfs.sh -pdb_name=bimbo01 -account_name=dbfsadm \
-account_password=dbfs -load_data
```

Le flag `-load_data` copie le contenu du répertoire courant, sert pour valider
le bon fonctionnement de `DBFS`.

Le FS créé se nomme `staging_area`, à ce stade son contenu n'est accessible qu'avec
la commande oracle `dbfs_client`, exemples :

```
oracle@srvbimbo01:BIMBO:dbfs> dbfs_client dbfsadm@pdbBIMBO01_oci --command ls dbfs:/staging_area/ < pass
Password:
dbfs:/staging_area/account.txt
dbfs:/staging_area/automount_dbfs.sh
dbfs:/staging_area/create_dbfs.sh
dbfs:/staging_area/create_dbfs_ressource.sh
dbfs:/staging_area/create_dbfs.sql
dbfs:/staging_area/create_user_dbfs.sql
dbfs:/staging_area/drop_all.sh
dbfs:/staging_area/drop_dbfs.sql
dbfs:/staging_area/nohup.out
dbfs:/staging_area/pass
dbfs:/staging_area/readme.md
dbfs:/staging_area/root_configure_dbfs.sh
oracle@srvbimbo01:BIMBO:dbfs>
```

Ne pas ajouter `*` pour lister le répertoire, la syntaxe `dbfs:/staging_area/*`
ne fonctionne pas.

Le fichier `account.txt` contiendra toutes les informations pour supprimer le
compte avec le script `drop_all.sh`

#### Rendre visible le FS `staging_area` depuis l'OS

Le but est de pouvoir accéder à `staging_area` depuis l'OS, pour notamment
pouvoir copier les fichiers à charger en base.

Avec le compte `root` exécuter le script `root_configure_dbfs.sh` :

```
[root@srvbimbo01 ~]# cd ~/plescripts/db/dbfs
[root@srvbimbo01 dbfs]# ./root_configure_dbfs.sh -service_name=pdbbimbo01_oci \
-dbfs_user=dbfsadm -dbfs_password=dbfs
```

Le script créé le point de montage `/mnt/dbfs` qui contiendra le FS `staging_area`
créé avec le script `oracle`.

L'entrée dans `/etc/fstab` permet de monter le fs avec la commande `mount /mnt/dbfs`
avec les comptes `oracle` ou `grid` (si le tnsnames.ora est configuré). Mais ce
n'est pas pratique, il faut saisir le mot de passe et la commande ne rend pas la
main, il faut donc faire :
```
nohup mount /mnt/dbfs < ~/plescripts/db/dbfs/pass &
```

Le script `automount_dbfs.sh` permet de lancer la commande en nohup, exemple :
```
oracle@srvbimbo01:BIMBO:dbfs> ./automount_dbfs.sh
# Running : ./automount_dbfs.sh

nohup: redirecting stderr to stdout
oracle@srvbimbo01:BIMBO:dbfs> cd /mnt/dbfs/staging_area/
oracle@srvbimbo01:BIMBO:staging_area> ll
total 18
-rw-rw-r-- 1 oracle oinstall   81 Dec 16 11:39 account.txt
-rwxr-xr-- 1 kangs  users     687 Dec 16 11:39 automount_dbfs.sh
-rwxrwxr-- 1 kangs  users    2794 Dec 16 11:39 create_dbfs.sh
-rwxr-xr-- 1 kangs  users    3510 Dec 16 11:39 create_dbfs_ressource.sh
-rw-r--r-- 1 kangs  users      77 Dec 16 11:39 create_dbfs.sql
-rw-rw-r-- 1 kangs  users     408 Dec 16 11:39 create_user_dbfs.sql
-rwxr-xr-- 1 kangs  users     478 Dec 16 11:39 drop_all.sh
-rw-r--r-- 1 kangs  users      64 Dec 16 11:39 drop_dbfs.sql
-rw------- 1 oracle oinstall  250 Dec 16 11:39 nohup.out
-rw-r--r-- 1 oracle oinstall    5 Dec 16 11:39 pass
-rw-rw-r-- 1 kangs  users    3045 Dec 16 11:39 readme.md
-rwxrwxr-- 1 kangs  users    3402 Dec 16 11:39 root_configure_dbfs.sh
```

Pour démonter le FS : `fusermount -u /mnt/dbfs`

#### Monter automatiquement le FS au démarrage de la base
C'est en cour, mais rien ne fonctionne correctement :
* Le script automatisant le nohup et le mot de passe à tendance à foirer, le
fichier tnsnames.ora est différent entre `oracle` et `grid` il faut donc copier
l'alias TNS.
* Configurer correctement le service dans le CRS, actuellement le service démarre
avant la base de donnée et donc ne fonctionne pas.

Le script en cour de réalisation est `create_dbfs_ressource.sh`
