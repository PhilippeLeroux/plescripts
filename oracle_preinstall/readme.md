## Oracle version : 12.1.0.2

### Compte oracle variable ORACLE_BASE & ORACLE_HOME identiques :
 * ORACLE_BASE == /u01/app/oracle
 * ORACLE_HOME == $ORACLE_BASE/12.1.0.2/dbhome_1

### Compte grid pour une standalone :
 * ORACLE_BASE == /u01/app/grid
 * ORACLE_HOME == ORACLE_BASE/12.1.0.2

### Compte grid pour un RAC :
 * ORACLE_BASE == /u01/app/grid
 * ORACLE_HOME == /u01/app/12.1.0.2/grid

### Cas particulier du FS
 * ORACLE_BASE == /u01/app/oracle
 * ORACLE_HOME == $ORACLE_BASE/12.1.0.2/dbhome_1
 * oradata     == $ORACLE_BASE/oradata/data
 * orafraa     == $ORACLE_BASE/oradata/fra

Dans cette configuration il faut minimum 20Gb pour /u01

Exemple de répartition :

	[root@srvracsan01 ~]# df -h /u01
	Filesystem                 Size  Used Avail Use% Mounted on
	/dev/mapper/vgorcl-lvorcl   32G   12G   21G  38% /u01

	[root@srvracsan01 app]# du -sh *
	6.5G    12.1.0.2
	78M     grid
	5.3G    oracle
	2.4M    oraInventory

## Evolution 3 disques.

### Compte oracle variable ORACLE_BASE & ORACLE_HOME identiques, ocfs2
 * ORACLE_BASE == /u01/app/oracle
 * ORACLE_HOME == $ORACLE_BASE/12.1.0.2/dbhome_1

Disque de 10Gb : 5.3Gb

### Compte grid pour une standalone, xfs
 * ORACLE_BASE == /u02/app/grid
 * ORACLE_HOME == ORACLE_BASE/12.1.0.2

Disque de 

### Compte grid pour un RAC, xfs
 * ORACLE_BASE == /u02/app/grid
 * ORACLE_HOME == /u02/app/12.1.0.2/grid

Disque de 10Gb	: 6.5G + 78M
