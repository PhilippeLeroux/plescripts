#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r ME=$0
typeset	-r PARAMS="$*"
typeset	-r str_usage=\
"Usage : $ME file_name
	Ex : gen_docs.sh *lib.sh
"

# $1 file name
#
# Variables declared in gen_temporary_docs :
#	$line is the function name
#	$comment_list contains all comments. comment_list is cleared on exit.
function print_function_definition
{
	echo "#### $line" >> $1
	typeset		comm
	for comm in "${comment_list[@]}"
	do
		# Passe le tag + l'espace donc 4 caractères.
		echo "	${comm:4:120}" >> $1 || true
	done
	echo "" >> $1

	comment_list=()
}

# incremente variables nr_pub, nr_priv & nr_undoc declared in function gen_doc.
function gen_temporary_docs
{
	typeset	-a	comment_list	# Contient tous les commentaire d'une fonction.
	typeset		line

	typeset		first_pub_found=no
	typeset		first_priv_found=no
	typeset		first_undoc_found=no

	typeset		tag_found=no
	typeset		tag_public="#*>"
	typeset		tag_private="#*<"

	typeset		line
	while read line
	do
		if [ "${line:0:${#tag_public}}" = "$tag_public" ]
		then
			tag_found=public
			if [ $first_pub_found == no ]
			then
				first_pub_found=yes
				echo "### Public functions" >> $doc_public
				echo "" >> $doc_public
			fi
			comment_list+=( "$line" )
		elif [ "${line:0:${#tag_private}}" = "$tag_private" ]
		then
			tag_found=private
			if [ $first_priv_found == no ]
			then
				first_priv_found=yes
				echo "### Private functions" >> $doc_private
				echo "" >> $doc_private
			fi
			comment_list+=( "$line" )
		elif [ $tag_found = public ]
		then
			# $line contient la déclaration de la fonction.
			print_function_definition $doc_public
			((++nr_pub))
			tag_found=no
		elif [ $tag_found = private ]
		then
			# $line contient la déclaration de la fonction.
			print_function_definition $doc_private
			((++nr_priv))
			tag_found=no
		elif [ "${line:0:8}" = "function" ]
		then
			if [ $first_undoc_found == no ]
			then
				first_undoc_found=yes
				echo "### Undocumented functions" >> $doc_no
				echo "" >> $doc_no
			fi
			# $line contient la déclaration de la fonction.
			print_function_definition $doc_no
			((++nr_undoc))
		fi
	done < $libname
}

# $1 lib name
function gen_doc
{
	typeset	-r	libname=$1
	typeset	-r	dir_name=~/plewiki
				doc_name=/tmp/${libname##*/}
	typeset	-r	doc_name=${doc_name%.*}.md
				md_name=$dir_name/shlibdocs/${libname##*/}
	typeset	-r	md_name=${md_name%.*}.md

	typeset	-r	doc_public=/tmp/doc_public.txt
	typeset	-r	doc_private=/tmp/doc_private.txt
	typeset	-r	doc_no=/tmp/doc_no.txt

	rm $doc_public $doc_private $doc_no 2>/dev/null

	if [ ! -d $dir_name ]
	then
		echo "Error '$dir_name' not exists."
		echo
		exit 1
	fi

	[ ! -d $dir_name/shlibdocs ] && mkdir $dir_name/shlibdocs || true

	info "Doc for $libname : $md_name"
	rm -f $doc_name

	# Les 3 variables sont incrémentées par gen_temporary_docs.
	typeset	-i	nr_pub=0
	typeset	-i	nr_priv=0
	typeset	-i	nr_undoc=0

	gen_temporary_docs

	rm $doc_name 2>/dev/null

	echo "" > $doc_name
	echo "## ${md_name##*/} : $(date +"%Y/%m/%d")" >> $doc_name
	echo "" >> $doc_name
	printf "* %02d %s\n" $nr_pub "publics functions" >> $doc_name
	printf "* %02d %s\n" $nr_priv "privates functions" >> $doc_name
	printf "* %02d %s\n" $nr_undoc "undocumented functions" >> $doc_name
	echo "" >> $doc_name
	echo "--------------" >> $doc_name

	printf "  %2d %s\n" $nr_pub "publics functions."
	[ -f $doc_public ] && cat $doc_public >> $doc_name || echo "" >>$doc_name
	echo "" >> $doc_name
	[ -f $doc_public ] && echo "--------------" >> $doc_name || true

	printf "  %2d %s\n" $nr_priv "privates functions."
	[ -f $doc_private ] && cat $doc_private >> $doc_name || echo "" >>$doc_name
	echo "" >> $doc_name
	[ -f $doc_private ] && echo "--------------" >> $doc_name || true

	printf "  %2d %s\n" $nr_undoc "undocumented functions." || echo "" >>$doc_name
	[ -f $doc_no ] && cat $doc_no >> $doc_name || true
	echo "" >> $doc_name
	[ -f $doc_no ] && echo "--------------" >> $doc_name || true

	gh-md-toc $doc_name | head -n -2 | sed "s/^    //g" > $md_name
	cat $doc_name >> $md_name
	rm -f $doc_name
	LN
}

[ $# -eq 0 ] && info "$str_usage" && exit 1

while [ $# -ne 0 ]
do
	case $1 in
		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			gen_doc $1
			shift
			;;
	esac
done
