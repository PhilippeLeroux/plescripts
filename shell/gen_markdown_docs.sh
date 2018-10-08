#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r ME=$0
typeset	-r PARAMS="$*"

function print_usage
{
	echo
	echo "Usage :"
	echo "    ${ME##*/}"
	echo "        [-no_TOC] do not generate TOC. Must be first parameter."
	echo "        [file name] (*lib.sh work.)"
	echo "        [-search=pattern]"
	echo "        [-no_index] do not generate file index.md."
	echo
	echo "   Ex : $ ${ME##*/} *lib.sh"
	echo "        $ ${ME##*/} -search=\"*lib.sh\""
	echo
	echo "L'indexe sera généré pour tous les scripts. Si un seul script est"
	echo "passé utiliser -no_index, mais si le script est dans l'indexe les"
	echo "information le concernant ne seront pas mises à jour."
	echo
	echo "Les commentaires pris en compte sont :"
	echo "    #*> pour une fonction public."
	echo "    #*< pour une fonction privée."
	echo "Les commentaires normaux sont ignorés."
	echo
	echo "Les fonctions doivent être déclarées ainsi : function nom"
	echo
}

# Print comments of current function to stdout.
#
# $1 "Private ", "Public " or nothing.
#
# Variables declared in gen_tmp_markdowns_for :
#	$line contains the function name.
#	$comment_list contains all comments. comment_list is cleared on exit.
function print_function_comments
{
	echo "#### $1$line"
	typeset		comm
	for comm in "${comment_list[@]}"
	do
		# Passe le tag + l'espace donc 4 caractères.
		echo "	${comm:4}"
	done
	echo ""

	comment_list=()
}

# $1 file name.
#
# Generate markdowns : md_func_publics, md_func_privates and md_func_undoc.
#
# Increment variables nr_pub, nr_priv and nr_undoc declared in function
# gen_markdown_doc_for.
function gen_tmp_markdowns_for
{
	typeset	-r	libname=$1

	typeset	-a	comment_list	# Contient tous les commentaires d'une fonction.
	typeset		line

	typeset		first_pub_found=no
	typeset		first_priv_found=no
	typeset		first_undoc_found=no

	typeset	-r	tag_public="#*>"
	typeset	-r	tag_private="#*<"
	typeset		tag_found=no

	typeset		line
	while IFS= read line
	do
		if [ "${line:0:${#tag_public}}" == "$tag_public" ]
		then
			tag_found=public
			if [ $first_pub_found == no ]
			then
				first_pub_found=yes
				echo "### Public functions" >> $md_func_publics
				echo "" >> $md_func_publics
			fi
			comment_list+=( "$line" )
		elif [ "${line:0:${#tag_private}}" == "$tag_private" ]
		then
			tag_found=private
			if [ $first_priv_found == no ]
			then
				first_priv_found=yes
				echo "### Private functions" >> $md_func_privates
				echo "" >> $md_func_privates
			fi
			comment_list+=( "$line" )
		elif [ $tag_found == public ]
		then
			# $line contient la déclaration de la fonction.
			print_function_comments "Public " >> $md_func_publics
			((++nr_pub))
			tag_found=no
		elif [ $tag_found == private ]
		then
			# $line contient la déclaration de la fonction.
			print_function_comments "Private " >> $md_func_privates
			((++nr_priv))
			tag_found=no
		elif [ "${line:0:8}" == "function" ]
		then
			if [ $first_undoc_found == no ]
			then
				first_undoc_found=yes
				echo "### Undocumented functions" >> $md_func_undoc
				echo "" >> $md_func_undoc
			fi
			# $line contient la déclaration de la fonction.
			print_function_comments >> $md_func_undoc
			((++nr_undoc))
		fi
	done < $libname
}

# Print file $1 to stdout. Do nothing if file $1 not exists.
#
# Used variable : separator.
function print_to_stdout
{
	[ -f "$1" ] && cat "$1" && echo -e "$separator\n" || true
}

# Print to stdout statistics about current function.
#
# Used variables : nr_pub, nr_undoc and nr_priv
function print_stats_on_func
{
	echo "  * Publics functions      : $nr_pub"
	echo "  * Undocumented functions : $nr_undoc"
	echo "  * Privates functions     : $nr_priv"
}

# $1 lib name
#
# Print to stdout all documentation with markdown tags.
#
# Used variables : nr_pub, nr_undoc, nr_priv, md_name, libname and stats_libs_dic
function print_markdown_for
{
	typeset	-r	libname=$1

	# Est utilisé par la fonction print_to_stdout.
	typeset	-r	separator=$(fill - 80)

	typeset	-r	stats="$(print_stats_on_func)"
	stats_libs_dic+=( [$(cut -d. -f1<<<"${libname##*/}")]="$stats" )

	echo -e "## ${md_name##*/} : $(date +"%d/%m/%Y")\n"
	echo "$stats"
	echo -e "\n$separator\n"

	print_to_stdout $md_func_publics

	print_to_stdout $md_func_undoc

	print_to_stdout $md_func_privates
}

# $1 lib name
function gen_markdown_doc_for
{
	typeset	-ri	start_at=$SECONDS
	typeset	-r	libname=$1

	typeset	-r	md_func_publics=/tmp/$$_func_publics.md
	typeset	-r	md_func_privates=/tmp/$$_func_privates.md
	typeset	-r	md_func_undoc=/tmp/$$_func_undoc.md

	typeset		tmp_md=/tmp/$$_${libname##*/}
	typeset	-r	tmp_md=${tmp_md%.*}.md

	typeset		md_name=$wiki_dir/${libname##*/}
	typeset	-r	md_name=${md_name%.*}.md

	typeset	-i	nr_pub=0
	typeset	-i	nr_priv=0
	typeset	-i	nr_undoc=0

	# Sont créés les fichiers : md_func_publics, md_func_privates, md_func_undoc
	gen_tmp_markdowns_for "$libname"

	# Concaténation des stats et des fichiers md_func_*
	print_markdown_for "$libname" > "$tmp_md"

	if [ $TOC == yes ]
	then
		if [ $used_my_md_toc == yes ]
		then
			markdown_toc.sh -md="$tmp_md"
			mv "$tmp_md" "$md_name"
		else
			gh-md-toc "$tmp_md" | head -n -2 | sed "s/^    //g" > "$md_name"
			cat "$tmp_md" >> "$md_name"
		fi
	else
		mv "$tmp_md" "$md_name"
	fi

	rm -f $md_func_publics $md_func_privates $md_func_undoc "$tmp_md"

	info "Documentation for $1 : $(replace_paths_by_shell_vars $md_name) (~$(fmt_seconds $(( SECONDS-start_at ))))"
	echo
}

# Print to stdout markdown index.
#
# Used dic : stats_libs_dic
function print_markdown_index
{
	echo "Index :"
	echo "======="
	echo
	for libname in ${!stats_libs_dic[@]}
	do
		echo -n "[$libname](https://github.com/PhilippeLeroux/plescripts/wiki/$libname)"
		[ "$libname" == vboxlib ] && echo " : used the alias vmlib in scripts." || echo
		echo "${stats_libs_dic[$libname]}"
		echo
	done
}

function main
{
	typeset	-ri	begin_script=$SECONDS

	[ $# -eq 0 ] && print_usage && exit 1 || true

	typeset	-r	root_wiki=~/plewiki

	exit_if_dir_not_exists $root_wiki

	typeset	-r	wiki_dir=$root_wiki/shlibdocs

	[ ! -d $wiki_dir ] && mkdir $wiki_dir || true

	typeset	-r	used_my_md_toc=${USED_MY_MD_TOC:-yes}

	typeset	-i	nr_md=0		# Nombre de markdown générés.
	typeset		index=yes
	typeset		TOC=yes
	# Dictionnaire mémorisant chaque fonction de la lib, son associés les stats
	# sur les fonctions. Sera utilisé pour la génération de l'index.
	typeset	-A	stats_libs_dic

	echo

	while [ $# -ne 0 ]
	do
		case $1 in
			-h|-help|help)
				print_usage
				exit 1
				;;

			-no_index)
				index=no
				shift
				;;

			-no_TOC)
				TOC=no
				shift
				;;

			-search=*)
				typeset	-r	pattern="${1##*=}"
				shift

				set -f
				while read file
				do
					gen_markdown_doc_for $file
					((++nr_md))
				done<<<"$(find . -type f -name $pattern)"
				set +f
				;;

			*)
				exit_if_file_not_exists $1
				gen_markdown_doc_for $1
				((++nr_md))
				shift
				;;
		esac
	done

	if [ $index == yes ]
	then
		info "Generate markdown index : $(replace_paths_by_shell_vars $wiki_dir/index.md)"
		print_markdown_index > $wiki_dir/index.md
		echo
	fi

	info "$nr_md markdowns, total times : ~$(fmt_seconds $(( SECONDS-begin_script )))"
	LN
}

main "$@"
