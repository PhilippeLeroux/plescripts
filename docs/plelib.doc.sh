################################################################################
Resume 2016/09/24 :
~~~~~~~~~~~~~~~~~~~

# 43 publics functions
# 11 privates functions
# 0 undocumented functions

################################################################################
43 publics functions :
~~~~~~~~~~~~~~~~~~~~~~

#*> Remove all visual makers from file $1
function clean_log_file

#*> Hide cursor
function hide_cursor

#*> Show cursor
function show_cursor

#*> return number of col for the terminal
function term_cols

#*> Print error message
function error

#*> Print warning message
function warning

#*> Affiche les informations de debug.
#*> Actif uniquement si la variable DEBUG_MODE==ENABLE est définie.
#*> Fonction sur le même principe que info.
function debug

#*>	Print normal message
#*> Options
#*>   -n no new line
#*>   -f don't print info marker. (Useful after info -n)
function info

#*> line_separator [car]
#*> Fill line with charactere = or specified charactere
function line_separator

#*> New line
function LN

#*> Paramètres :
#*>
#*> -reply_list="y n" liste des réponses séparées par un espace, par défaut "y n"
#*>    * Pour la touche 'return' utiliser -reply_list=CR
#*>    * Maximum 3 réponses possibles.
#*>
#*> -print="y/n ?" les réponses à afficher, par défaut "y/n ?"
#*>
#*> Les autres paramètres forment la question.
#*>
#*>	Codes retours :
#*>		0	pour la première réponse.
#*>		1	pour la seconde réponse.
#*>		3	pour la troisième réponse.
#*>
function ask_for

#*> Pour les paramètres voir ask_for
#*> Si l'utilisateur répond non (la 2ième réponse) le script est terminé par un exit 1
function confirm_or_exit

#*> Fake exec_cmd command
#*> Command printed but not executed.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function fake_exec_cmd

#*> exec_cmd
#*> if EXEC_CMD_ACTION
#*>    == NOP  : command is printed (No Operation)
#*>    == EXEC : command is printed & executed
#*>
#*> If command failed stop the scripts.
#*>
#*> Parameters:
#*>		-f  EXEC_CMD_ACTION is ignored.
#*>		-c  continue on error.
#*>		-ci like -c but not print error message.
#*>		-h  hide command except on error.
#*>		-hf hide command even on error.
#*>
#*> Show execution time after PLE_SHOW_EXECUTION_TIME_AFTER seconds
function exec_cmd

#*> $1 parameter to add.
function add_dynamic_cmd_param

#*> run command '$@' with parameters define by add_dynamic_cmd_param
#*> if first parameter is -confirm a prompt is printed to confirm or not execution.
#*> For other parameters see exec_cmd
function exec_dynamic_cmd

#*> exit_if_file_not_exist <name> [message]
#*> if file <name> not exists, script aborted.
#*> Print [message] if specified.
function exit_if_file_not_exist

#*> exit_if_dir_not_exist <name> [message]
#*> if directory <name> not exits, script aborted.
#*> Print [message] if specified.
function exit_if_dir_not_exist

#*> update_value <var> <value> <file>
#*>	Update variable <var> from file <file> with value <value>
#*> If variable doesn't exist, it's added.
#*> If value = empty reset value but not remove variable.
#*>
#*>
#*> If file doesn't exist script aborted.
function update_value

#*> remove_value <var> <file>
#*>
#*> Remove variable <var> from file <file>
#*>		Format ^wars*=.*
#*>
#*> If file doesn't exist script aborted.
function remove_value

#*> exit_if_param_undef <var> [message]
#*>
#*> Script aborted if var == undef or == -1 or empty
function exit_if_param_undef #var_name

#*> exit_if_param_invalid var_name val_list [message]
#*>
#*> Script aborted if var
#*>		= undef or -1
#*>		not in the list val_list
function exit_if_param_invalid

#*> Double symbol % from $@.
function double_symbol_percent

#*> Escape " from $@
function escape_2xquotes

#*> Escape / from $@
function escape_slash

#*> Escape  from $@
function escape_anti_slash

#*> Upper case "$@"
function to_upper

#*> Lower case "$@"
function to_lower

#*> Upper case the first caractere of $1
function initcap

#*> fill <car> <no#>
#*> Return a buffer filled with no# characteres car
function fill

#*>	Temporisation pendant $1 secondes
#*>	$1 temps en secondes
#*>	$2 msg par défaut le message est "Be patient..."
function timing

#*> pause_in_secs <seconds>
#*> Fait une pause de <seconds> secondes.
#*> Le décompte du temps écoulé sera affiché à la position courante du curseur.
#*> Retourne la longueur utilisée pour afficher le décompte ce qui permet
#*> d'effacer l'affichage.
function pause_in_secs

#*> script_start
#*> A appelé en début de script.
function script_start

#*> script_stop <nom du script>
#*> $1 correspond à message
#*> Affiche le temps écoulé depuis le dernier appel à script_start
#*> Doit être appelé en fin de script
function script_stop

#*> Eval an arithmetic expression
#*> Flags
#*>    -l[#] : use real numbers with # number decimals
#*>    -i : remove all decimals
function compute

#*> fmt_seconds <seconds>
#*> <seconds> formate to the better format
function fmt_seconds # $1 seconds

#*> fmt_number <number>
#*> Format number english or french, use LANG to define the format.
#*>
function fmt_number

#*> fmt_kb2mb <size>
#*>	convert <size> in Kb to Mb and format.
function fmt_kb2mb

#*> to_mb string_size
#*> Convert string_size in Mb
#*>		Last digits is the unit : G, Gb, M, Mb, Kb or K
#*>		no digit for byte.
function to_mb

#*> Convert value $1 to bytes
#*> Units can be b,k,m or g (or upper case)
function convert_2_bytes

#*> Convert value $1 to better.
#*> Units can be b,k,m or g (or upper case)
#*>
#*> 1024K == 1Mb
#*> 1024M == 1Gb
function fmt_bytesU_2_better

#*> return 0 if cmd $1 exists else return 1
function test_if_cmd_exists

#*> return 0 if rpm update available else return 1
#*> check update on server $1 (optional)
function test_if_rpm_update_available


################################################################################
0 undocumented functions :
~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
11 privates functions :
~~~~~~~~~~~~~~~~~~~~~~~

#*< Active les effets visuels couleurs et autres.
function enable_markers

#*< Désactive les effets visuels couleurs et autres.
function disable_markers

#*< Remove all visual makers for log file generate by plelib
function clean_plelib_log_file

#*< Show cursor on Ctrl+c
function ctrl_c

#*< Used by fonctions info, warning and error.
#*< Action depand of PLELIB_OUTPUT
#*<		DISABLE : no visual effects.
#*<		ENABLE	: visual effects
#*<		FILE	: write into $PLELIB_LOG_FILE without any effects and canal 1 with visual effects.
function my_echo

#*< Extrait la commande de "$@"
#*< Si la première commande est ssh alors recherche la commande exécutée par ssh
function get_cmd_name

#*<	Test if a variable exists, format ^var\s*=\s*value
#*<	1	variable name
#*<	2	file name
function exist_var

#*< change_value <var> <value> <file>
#*<	Format ^var\s*=\s*value
function change_value

#*< add_value <var> <value> <file>
#*< Format : var=value
#*< If <value> == empty no value specified.
function add_value

#*<	Format ^var\s*=\s*value
#*< Sert pour le debuggage.
#*< Si des paramètres sont passés il sont affiché comme un message.
#*< Pour que la fonction soit active il faut positionner la variable PAUSE à ON
function test_pause # $1 message

#*< get_initiator_for <db> <#node>
#*< return initiator name for <db> and node <#node>
function get_initiator_for

