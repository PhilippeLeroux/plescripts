-- vim: ts=4:sw=4


alter pluggable database &1$seed close immediate instances=all;
alter pluggable database &1 close immediate instances=all;
drop pluggable database &1$seed including datafiles;
drop pluggable database &1 including datafiles;
