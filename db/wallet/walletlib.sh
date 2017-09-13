# vim: ts=4:sw=4

# Le script /u02/app/oracle/12.2.0.1/dbhome_1/install/root_schagent.sh exécuté
# par le script root.sh après l'installation d'Oracle créé le répertoire :
# $ORACLE_HOME/data/wallet
# Mais mes scripts ne peuvent pas l'utiliser car si le répertoire existe je
# considère que le wallet est installé.
# Note : le script Oracle positionne les droits 700 sur le répertoire.
typeset -r wallet_path=${ORA_WALLET-$ORACLE_HOME/oracle/wallet}

#*> return 0 if wallet on CFS else return 1
function wallet_store_on_cfs
{
	[ ! -d $wallet_path ] && return 1 || true

	typeset -r test_file=$wallet_path/is_cfs
	touch $test_file
	ssh ${gi_node_list[0]} test -f $test_file
	typeset is_cfs=$?
	rm $test_file
	return $is_cfs
}
