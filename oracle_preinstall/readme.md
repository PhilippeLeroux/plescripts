### Oracle version : 12.1.0.2

Variables du fichier `global.cfg` agissant sur ces scripts :
 * Ajustement de la 'shared memory'
 * Disques pour le Grid Infra et le noyau Oracle.
 * Localisation des répertoires d'installations des binaires Oracle.
 * Choix du FS utilisé pour le noyau Oracle RAC.
 * ...

Utilisation des 'tuned profile' pour :
 * la mise en œuvre des préconisations Oracle concernant les performances.
 * la mise en œuvre des 'Huge pages'.

#### Compte oracle 
 * ORACLE_BASE = /$ORCL_DISK/app/oracle
 * ORACLE_HOME = $ORACLE_BASE/12.1.0.2/dbhome_1

#### Compte grid pour une standalone
 * ORACLE_BASE = /$GRID_DISK/app/grid
 * ORACLE_HOME = ORACLE_BASE/12.1.0.2

#### Compte grid pour un RAC
 * ORACLE_BASE = /$GRID_DISK/app/grid
 * ORACLE_HOME = /$GRID_DISK/app/12.1.0.2/grid

#### Cas particulier du FS (ne fonctionne peut être plus)
 * ORACLE_BASE = /$ORCL_DISK/app/oracle
 * ORACLE_HOME = $ORACLE_BASE/12.1.0.2/dbhome_1
 * oradata     = $GRID_DISK/oradata/data
 * orafraa     = $GRID_DISK/oradata/fra
