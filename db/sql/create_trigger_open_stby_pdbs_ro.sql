-- vim: ts=4:sw=4
create or replace
trigger open_stby_pdbs_ro after startup on database
begin
--	Le trigger doit être crée sur le CDB.
--
--	Lors d'un switch over, sur la base créée en standby, les PDBs ne sont pas
--	ouverts même avec l'option save state.
--	Par contre si on reswitch sur la base initialement en Primaire les PDBs sont
--	bien ouvert en RW.
--
--	Donc je ne teste plus le rôle de la base.
	execute immediate 'alter pluggable database all open';

--	Acien code.
--	if sys_context('USERENV', 'DATABASE_ROLE') = 'PHYSICAL STANDBY'
--	then
--		execute immediate 'alter pluggable database all open';
--	end if;
end open_stby_pdbs_ro;
/
