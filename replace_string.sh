#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-path=str] Chemin ou commencer la recherche, par défaut ~/plescripts
	[-readme]   Remplacer uniquement dans les fichiers readme.txt & README.md
	-str        Chaîne à remplacer.
	-by         Chaîne de remplacement.
"

typeset		str=undef
typeset		by=undef
typeset -r	default_root_path=~/plescripts
typeset		root_path=$default_root_path
typeset		readme_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-readme)
			readme_only=yes
			shift
			;;

		-path=*)
			root_path=${1##*=}
			shift
			;;

		-str=*)
			str=${1##*=}
			shift
			;;

		-by=*)
			by=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef str	"$str_usage"
exit_if_param_undef by	"$str_usage"

function replace
{
	typeset -r cmd_find="$@"

	typeset -i count_modified_files=0

	fake_exec_cmd "$cmd_find"
	while read file_name
	do
		grep -E "\<$str\>" $file_name >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
			info "Update $file_name"
			sed -i "s#\<$str\>#$by#g" $file_name
			count_modified_files=count_modified_files+1
		fi
	done<<<"$(eval $cmd_find)"
	LN
	info "$count_modified_files files updated."
}

if [ $readme_only = yes ]
then
	cmd_find="find $root_path/*"' -name readme.txt -or -name README.md'
	replace "$cmd_find"
	exit 0
fi

cmd_find="find $root_path/*"' -name "*.sh" -or -name "*.cfg" -or ! -name "[!^.]*" '
replace "$cmd_find"
LN

if [ "$root_path" = "$default_root_path" ]
then
	cmd_find="find $root_path/shell/ -type f"
	replace "$cmd_find"
	LN
fi
