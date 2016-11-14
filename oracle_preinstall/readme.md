## Oracle version : 12.1.0.2

### Compte oracle variable ORACLE_BASE & ORACLE_HOME identiques :
 * ORACLE_BASE == /$ORCL_DISK/app/oracle
 * ORACLE_HOME == $ORACLE_BASE/12.1.0.2/dbhome_1

### Compte grid pour une standalone :
 * ORACLE_BASE == /$GRID_DISK/app/grid
 * ORACLE_HOME == ORACLE_BASE/12.1.0.2

### Compte grid pour un RAC :
 * ORACLE_BASE == /$GRID_DISK/app/grid
 * ORACLE_HOME == /$GRID_DISK/app/12.1.0.2/grid

### Cas particulier du FS
 * ORACLE_BASE == /$ORCL_DISK/app/oracle
 * ORACLE_HOME == $ORACLE_BASE/12.1.0.2/dbhome_1
 * oradata     == $GRID_DISK/oradata/data
 * orafraa     == $GRID_DISK/oradata/fra
