#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME file_name
	Ex : gen_docs.sh *lib.sh
"

function write_para
{
	typeset -r title="$1"
	typeset -r doc_name="$2"

	echo "$(fill "#" 80)" >> $doc_name
	echo "$title" >> $doc_name
	echo "$(fill "~" ${#title})" >> $doc_name
	echo "" >> $doc_name

}

function gen_doc
{
	typeset -r	name=$1
	typeset		doc_name=~/plescripts/docs/${name##*/}
	doc_name=${doc_name%.*}.doc.sh

	typeset -r	doc_public=/tmp/doc_public.txt
	typeset -r	doc_private=/tmp/doc_private.txt
	typeset -r	doc_no=/tmp/doc_no.txt

	rm $doc_public $doc_private $doc_no 2>/dev/null

	[ ! -d ~/plescripts/docs ] && mkdir ~/plescripts/docs

	info "Doc for $name"
	info "Doc : $doc_name"
	chmod +w $doc_name >/dev/null 2>&1

	typeset tag_found=no
	typeset tag_public="#*>"
	typeset tag_private="#*<"

	typeset -i	count_pub=0
	typeset -i	count_priv=0
	typeset -i	count_undoc=0

	while read line
	do
		if [ "${line:0:${#tag_public}}" = "$tag_public" ]
		then
			tag_found=public
			echo "$line" >> $doc_public
		elif [ "${line:0:${#tag_private}}" = "$tag_private" ]
		then
			tag_found=private
			echo "$line" >> $doc_private
		elif [ $tag_found = public ]
		then
			echo "$line" >> $doc_public
			echo "" >> $doc_public
			count_pub=count_pub+1
			tag_found=no
		elif [ $tag_found = private ]
		then
			echo "$line" >> $doc_private
			echo "" >> $doc_private
			count_priv=count_priv+1
			tag_found=no
		elif [ "${line:0:8}" = "function" ]
		then
			echo "$line" >> $doc_no
			echo "" >> $doc_no
			count_undoc=count_undoc+1
		fi
	done < $name

	rm $doc_name 2>/dev/null

	write_para "Resume $(date +"%Y/%m/%d") :" $doc_name
	echo "# $count_pub publics functions" >> $doc_name
	echo "# $count_priv privates functions" >> $doc_name
	echo "# $count_undoc undocumented functions" >> $doc_name
	echo "" >> $doc_name

	write_para "$count_pub publics functions :" $doc_name
	cat $doc_public >> $doc_name
	echo "" >> $doc_name

	write_para "$count_undoc undocumented functions :" $doc_name
	[ -f $doc_no ] && cat $doc_no >> $doc_name
	echo "" >> $doc_name

	write_para "$count_priv privates functions :" $doc_name
	[ -f $doc_private ] && cat $doc_private >> $doc_name

	chmod -w $doc_name
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

