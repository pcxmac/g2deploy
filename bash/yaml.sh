#!/usr/bin/env bash

# return a pad, given the argument's value (white space)
function yamlPad()
{
	local _length=${1:?}
	printf '%s\n' "$(printf "%*s%s" ${_length})"
}

function yamlPadL()
{
	local _key_value=${1:?}
	_key_value="$(( $(printf '%s\n' ${_key_value} | awk -F '[^ ].*' '{print length($1)}') ))"
	printf '%s\n' "${_key_value}"
}

# yaml standardization [charcater format/spec] formula
function yamlStd()
{
	local _tab=2
	local tabLength=""
	local _yaml

	# option to use string or file

	[[ -p /dev/stdin ]] && { _yaml="$(cat -)"; } || { _yaml="${1:?}"; }
	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	# filtration
	_yaml="$(printf "${_yaml}" | sed 's/#.*$//')";						# clear out comments
	_yaml="$(printf "${_yaml}" | sed '/^[[:space:]]*$/d')";				# delete empty lines
	_yaml="$(printf "${_yaml}" | sed 's/[^A-Za-z0-9_.:/*-\s ]//g')";	# filter out invalid characters
	_yaml="$(printf "${_yaml}" | sed 's/:[[:space:]]*/:/g;')";			# get rid of space between values, and :

	# root node, is assumed to be the first entry, it will have the root offset, this should be zero.
	_tmp="$(sed -n '1p' < <(printf '%s\n' $_yaml))"
	offset="$(printf '%s\n' ${_tmp} | awk -F '[^ ].*' '{print length($1)}')"

	# determine the spec tab length, it will be changed to/remain two.
	IFS=''
	while read -r line
	do
		tabLength="$(printf '%s\n' ${line} | awk -F '[^ ].*' '{print length($1)}')"
		[[ -n ${tabLength} ]] && { break; } 
	done < <(printf '%s\n' "${_yaml}" | \grep -iP '^\s.*[a-z]')
	IFS="${_tmp}"

	# rebuild yaml with 2x tabs
	IFS=''
	while read -r line
	do
		# GENERATE
		padLength="$(( $(printf '%s\n' ${line} | awk -F '[^ ].*' '{print length($1)}') ))"
		padLength=$((_tab*(padLength-offset)/tabLength))
		fLine="$(yamlPad $((padLength)))$(printf '%s\n' ${line} | sed 's/ //g')"
		printf '%s\n' "${fLine}"
	done < <(printf '%s\n' "${_yaml}")
	IFS="${_tmp}"
}

# picks out list items, or values from key-value pairs
function yamlValue()
{
	local stdYAML
	stdYAML="${1:?}"
	printf '%s\n' "${stdYAML}" | sed 's/ //g; s/^-//; s/[^:]*://g';
}

# return the number of elements in a yaml path, ie [ root/partition/directory/leaf ]
function yamlPathL()
{
	local _string="${1:?}"

#	_string="$(yamlStd ${_string})"

    local count=0
    while [ ${_string} != ${_string#*/} ]
    do
        count=$((count+1))
		_string="${_string#*/}"
	done
	printf '%s\n' "${count}"  # print length of address
}

# [cursor] : [remainder] : [current path]
function yamlPath() 
{
	# last slash added to ensure conditional statement inside for loop terminates when last two keys are the same, ie. ../disk/disk
	local _string="${1:?}"
	local _order="${2:?}"
	local _match=""

	#_string="$(yamlStd ${_string})"

	for ((i=0;i<${_order};i++))
	do
		_match="${_string%%/*}"
		_string="${_string#*/}"
		if [[ ${_match} == "${_string}" ]]
		then
			printf '%s\n' $_match
			_string=""
			break;
		fi
	done
	_prior="${1%/${_string}*}"
	# returns sought after key/value + remaining search pattern. There should be no white space between or after key-value pairs.
	printf '%s\t%s\t%s\n' "${_match}" "${_string}" "${_prior}" | sed 's/ //g' | sed 's:/*$::';                  
	#echo -e "${_match}\t${_string}"                 # returns sought after key/value + remaining search pattern
}

# displays the Nth element in a yaml path-address
function yamlOrder()
{
	# last slash added to ensure conditional statement inside for loop terminates when last two keys are the same, ie. ../disk/disk
	# " \\ " added to help disable matching of next path element,

	local _remainder="${1:?}/"
	local _order="$((${2:?}))"

	local _prune=""
	#_string="$(yamlStd ${_string})"

	for ((i=0;i<=${_order};i++))
	do
		#echo "$i $_prune :: $_remainder"
		_prune="${_remainder%%/*}"
		_remainder="${_remainder#*/}"

		# no way to delimit nested lists, need to think about the syntax rules surrounding multiple lists, no values, etc...
		#[[ $_prune == "-" ]] && { 
		#	_remainder="${_remainder}"
		#	_prune="${_prune}/${_remainder}"
		#	_remainder="${_remainder#*:*/}"
		#	_prune="${_prune%%/$_remainder}"
		#}
		#printf '%s | %s \n' "$_prune" "$_remainder"

	done
	# returns sought after key/value + remaining search pattern
	#printf '%s | %s\n' "${_prune}" "${_remainder}" | sed 's:/*$::';  
	printf '%s\n' "${_prune}"          
}

# finds a value in a yaml object, specific key-values filter out particular branches
#	1	if tab < cp, cp = tab (current match)
#	2	if match, cp ++							... this will satisfy the 'list' cycle
#	3	if match & no next, print result (end of search path)
function findKeyValue() 
{
	# cursor position
	local cp=0
	# actual number of tabs between key-value and left-most
	local tabLength
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	# path length, to determine target leaf/node
	local pLength="$(yamlPathL $_path)"
	#standardize input
	_yaml="$(yamlStd ${_yaml})"
	# strings, about which path is articulated
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		tabLength="$(( $(yamlPadL ${line})/2 ))"

		# if moving outside the scope of the current cursor
		[[ $((tabLength)) < $((cp)) ]] && 
		{ 
			cp="$((tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((tabLength*2))}$(printf '%s\n' "${cv}").*$")";
			next="$(yamlOrder ${_path} $((cp+1)))";
	 	} || { 
			match="";
			next="trivial";
		}

		[[ -n ${match} ]] && 
		{ 
			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); }
			# cv only changes on a match
			cv="$(yamlOrder ${_path} ${cp})";
		}

		 # EXECUTOR
		[[ -n "${match}" && -z ${next} ]] && { 
			printf '%s\n' "$(yamlValue $line)"
		}

	done < <(printf '%s\n' "${_yaml}")
}

# INSERT KEY VALUE
# REMOVE KEY VALUE
# MODIFY KEY VALUE

# finds a [KEY:VALUE] pair in a yaml object, modifies it's [VALUE], and dumps the YAML OBJECT
#	1	if match, print modified value
#	2	print if no match
# function modifyKeyValue()
# {
# 	# cursor position
# 	local cp=0
# 	# actual number of tabs between key-value and left-most
# 	local tabLength
# 	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
# 	local _path="${2:?}"
# 	# path length, to determine target leaf/node
# 	local pLength="$(yamlPathL $_path)"
# 	#standardize input
# 	_yaml="$(yamlStd ${_yaml})"
# 	# strings, about which path is articulated
# 	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
# 	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";

# 	IFS=''
# 	# pWave constructor
# 	while read -r line
# 	do
# 		# GENERATOR
# 		tabLength="$(( $(yamlPadL ${line})/2 ))"

# 		# if moving outside the scope of the current cursor
# 		[[ $((tabLength)) < $((cp)) ]] && 
# 		{ 
# 			cp="$((tabLength))";
# 			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
# 		}

# 		# DETERMINANAT
# 		[[ $((tabLength)) == $((cp)) ]] && {
# 		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((tabLength*2))}$(printf '%s\n' "${cv}").*$")";
# 			next="$(yamlOrder ${_path} $((cp+1)))"
# 	 	} || { 
# 			match="";
# 			next="trivial"
# 		}

# 		[[ -n ${match} ]] && 
# 		{ 
# 			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); }
# 			# cv only changes on a match
# 			cv="$(yamlOrder ${_path} ${cp})";
# 		}

# 		#  # EXECUTOR
# 		# [[ -n "${match}" && -z ${next} ]] && {
# 		# 	# PRINT MODIFIED KEY_VALUE
# 		# 	modLine="$(yamlPad $((padLength)))$(printf '%s:%s\n' "${key}" "${value} | sed 's/ //g')";
# 		# 	printf '%s\n' "$(yamlValue $line)";
# 		# } || {
# 		# 	# PRINT UNMODIFIED KEY_VALUE
# 		# 	printf '%s\n' "$(yamlValue $line)";
# 		# }

# 	done < <(printf '%s\n' "${_yaml}")
# }







































































#			next="$(yamlOrder ${_path} $((tabLength/2)))"

	#((counter+=1))
	#echo "[$tabLength < $cp]"
	#echo "path = $_path"
	#echo "root = $cv / path = $_path ; @ $tabL"
	#echo "-------------------------------------------------"

	# positive logic loop


		#[[ -z "${match}" && ${listing} == "true" ]] && { echo "fucktwat"; }

		#echo "-> setup,$cp"
 
		#      count tL   cp  fLine cv next   match
		#printf '%3d>[%2d:%2d]%s/[%s>%s]/@%s...\n' "$counter" "$tabLength" "$((cp*tabL))" "$fLine" "$cv" "$next" "$match"


		# if tabLength is less than the cursor, reset cursor (cv), the position assumes =tabLength
		#echo "[${tabLength} : $((cp*tabL))]" 
		#echo "tab length = $tabLength ; cp = $cp"

	 	#cursor="$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g')";

		#echo "$line :: $(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"

		#echo "[${tabLength},$((cp*tabL))]$line :: ${cursor},${listing} :: ${match}"
		#echo "[${tabLength}|${cs}]$line < $match | $rem "

		#[[ -z "${rem}" && -n "${match}" ]] && [[ ${listing} == "false" ]] {
			#[[ ${match#*:} == ${match} ]] && {
		 		#echo "---${match#*-}--- ---${rem}--- && ${match} && ${listing} == false $cv" | sed 's/^[ \t]*//';
		 	#} || {
		 		#echo ":::${match#*:}::: :::${rem}::: && ${match} && ${listing} == false $cv" | sed 's/^[ \t]*//';
		 	#}			 
		 	#listing="true"; 
		#}

		# if no longer matching, whether listing or scanning, advance cursor, disable listing
		# [[ -z "${match}" ]] && 
		# { 
		# 	# cursor forward in the path
		# 	cursor="$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g')";
		# 	cp=$((cp+1));
		# 	cv="$(yamlOrder "${_path}" ${cp})"; 
		# 	listing="false"
		# }


		#echo "<${tabLength}>[$cp] > <$line> ($match) [$cv]"
		#echo "[${tabLength}:${cp}]$line ++$match++ , $cv"
		#echo "$(yamlOrder "${_path}" ${cp}) [${tabLength}|${cp}]${line} < $match | $rem /${listing}"
		#rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"


# add a key-value pair as the last child, under the guardianship of the prefix path, ie [root/partition/path/prefix/ KEY:VALUE]
# checks for existing KEY:VALUE, same keys can exist with in a prefix/parent branch
# function insertKeyValue() 
# {
# 	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
# 	local _path="${2:?}"
# 	local tabL="$(yamlTabL "${_yaml}")"
# 	local cp=1
# 	local listing="false"
# 	local cv="$(yamlOrder "${_path}" ${cp})"
# 	local cs=$(( tabL*(${cp}-1) ))
	
# 	if [[ -n $(findKeyValue ${_yaml} ${_path}) ]] && { echo "-------------------------------------found"; } 

# 	# option to use string or file
#  	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

# 	# positive logic loop
# 	IFS=''
# 	while read -r line
# 	do

# 		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}') ))"
# 		match="$(echo ${line} | \grep -P "^\s{$cs}$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
# 		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"

# 		if [[ ${tabLength} < ${cs} ]] && { echo "SHIT !"; listing="false"; }
# 		[[ -z "${rem}" && -n "${match}" ]] &&
# 		{
# 			#echo "----------------LIMIT"
# 			# if [[ ${match#*:} == ${match} ]]
# 			# then
# 			# 	echo "${match#*-}" | sed 's/^[ \t]*//';
# 			# else
# 			# 	echo "${match#*:}" | sed 's/^[ \t]*//';
# 			# fi			 
# 			listing="true"; 
# 		}
# 		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
# 		[[ -z "${match}" && ${listing} == "true" ]] && { listing="false"; echo "[${tabLength}|${cs}]$(yamlPad $((tabLength)))<><>NEW CHILD<><>"; }

# 		echo "[${tabLength}|${cs}]$line"

# 		cs=$(( tabL*(${cp}-1) ))
# 	done < <(echo -e "${_yaml}")
# }

# function insertKeyValue() 
# {
# 	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
# 	local _path="${2:?}"
# 	local tabL="$(yamlTabL "${_yaml}")"
# 	local cp=1
# 	local listing="false"
# 	local cv="$(yamlOrder "${_path}" ${cp})"
# 	local ws=$(( tabL*(${cp}-1) ))
	
# 	# option to use string or file
#  	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

# 	key=${_path##*/}
# 	key=${key%:*}
# 	value=${_path##*/}
# 	value=${value#*:}

# 	_path=${_path%/*}

# 	echo "path = $_path :: key = ${key} , value = ${value}"

# 	# positive logic loop
# 	IFS=''
# 	while read -r line
# 	do
# 		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}')/2 +1))"
# 		match="$(echo ${line} | \grep -P "^\s{$ws}$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
# 		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"
# 		echo $line
# 		[[ -z "${rem}" && -n "${match}" ]] && {	listing="true"; $((cp+1)); }
# 		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
# 		[[ -z "${match}" && ${listing} == "true" ]] && { listing="done"; }
# 		[[ ${listing} == "done" ]] && { listing="false"; echo "----------------- END."; }
# 		ws=$(( tabL*(${cp}-1) ))
# 	done < <(echo -e "${_yaml}")
# }

# function znsertKeyValue() 
# {

# 	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
# 	local _path="${2:?}"
# 	local tabL="$(yamlTabL "${_yaml}")"
# 	local cp=1
# 	local listing="false"
# 	local cv="$(yamlOrder "${_path}" ${cp})"
# 	local ws=$(( tabL*(${cp}-1) ))

# 	operator=${_path##*/}
# 	_path=${_path%/*}
# 	newV=""
# 	#newV=${operator##*:}
# 	key=${operator%%:*}
# 	if [[ $operator != ${key} ]] && newV=${operator##*:}



# 	echo "_path = $_path | newv = $newV | key = $key"

#  	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

# 	IFS=''

# 	while read -r line
# 	do
# 		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}')/2 +1))"
# 		match="$(echo ${line%:*} | \grep -P "^\s{$ws}$(echo ${cv%:*} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
# 		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"
# 		[[ -z "${rem}" && -n "${match}" ]] &&
# 		{
# 			listing="true";
# 			((cp+=1))
# 		}
# 		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
# 		[[ -z "${match}" && ${listing} == "true" && ${tabLength} < "${cp}" ]] && { listing="done"; }

# 		if [[ ${listing} == "done" ]]
# 		then
# 			tabS="$( printf "%*s%s" $((cp*tabL-tabL)) )"
# 			newLine="${tabS}${key}:${newV}"
# 			if [[ "${match#*:}" == "${match}" ]]
# 			then
# 				echo "${cn} ${newLine}" | sed 's/^[ \t]*//';
# 			else
# 				echo "${cn} ${newLine}" | sed 's/^[ \t]*//';
# 			fi
# 			listing="false"
# 		fi

# 		ws=$(( tabL*(${cp}-1) ))
# 		echo "$tabLength $line"
# 	done < <(echo -e "${_yaml}")
# }


# function modifyKeyValue() {

# 	local _yaml="${1:?}"					# YAML FILE, 2 spaced.
# 	local _path="${2:?}"					#
# 	local _mode="${3:?}"					# 
# 	local tabL="$(yamlTabL "${_yaml}")"
# 	local cp=1
# 	local listing="false"
# 	local cv="$(yamlOrder "${_path}" ${cp})"	
# 	local ws=$(( tabL*(${cp}-1) ))
# 	local orderLength
# 	local _target
# 	local _value

#  	# option to use string or file
#  	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

# 	orderLength="$(yamlLength "${_path}")"

#  	if [[ ${_mode} == "-i" || ${_mode} == "-m" ]]	# INSERTS ONE BRANCH OR LEAF IN TO SUBSET OF TARGET
#  	then 
#  		_target="$(echo "$(yamlOrder "${_path}" $((orderLength-1)))" | awk '{print $3}' | sed 's/[][]//g')";
#  		_value="$(echo "$(yamlOrder "${_path}" $((orderLength-1)))" | awk '{print $2}' | sed 's/[][]//g')";
#  	fi
#  	if [[ ${_mode} == "-r" ]]	# RECURSIVE DELETE (EFFECTIVELY, PRUNES EVERY BRANCH/LEAF TO INCLUDE TARGET, OF)
#  	then 
#  		_target="${_path}";
#  		_value="";
#  	fi
#  	if [[ ${_mode} == "-m" ]]	# MODIFY EXISTING KEY/VALUE PAIR W. KEY:VALUE:NEW_VALUE
#  	then
# 		_target="${_path%:*}"
#  		_value="${_value%%:*}:${_value##*:}"
#  	fi

# 	echo "target = ${_target} . key/value.target = ${_value} : order length = ${orderLength}"

# 	# positive logic loop
# 	IFS=''
# 	while read -r line
# 	do
# 		echo $match
# 		match="$(echo ${line} | \grep -P "^\s{$ws}$(echo ${cv} | awk '{print $1}')")"
# 		rem="$(echo ${cv} | awk '{print $2}')"
# 		#echo "rank = ${ws} | search = ${cv} | match = ***${match}*** : ${line}"
# 		# success ?
# 		#[[ ${listing} == "true" && ]]
# 		[[ ${cp} == $((orderLength-1)) && -n "${match}" ]] && { listing="true"; }
# 		# if a match is found, advance.		[[ YES MATCH ]]
# 		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp})"; }
# 		[[ -z "${match}" && ${listing} == "true" ]] && { echo "${_value}"; }
# 		ws=$(( tabL*(${cp}-1) ))
# 	done < <(echo -e "${_yaml}")
# }

	# alternate source provider


	std_o="# Install Config for @ ${dhost}:123456\n"
	std_o="${std_o}  install: ${dpool}/${ddataset}\n"
	std_o="${std_o}    disks: ZORO\n"
	std_o="${std_o}      - /dev/sda3\n"
	std_o="${std_o}      - /dev/sdb3\n"
	std_o="${std_o}      - /dev/sdc3\n"
	std_o="${std_o}      - /dev/sdd3\n"
	std_o="${std_o}      pool: ${dpool}\n"
	std_o="${std_o}      dataset: ${ddataset}\n"
	std_o="${std_o}      path: ${dpath}\n"
	std_o="${std_o}      format: zfs\n"
	std_o="${std_o}      compression: lz4\n"
	std_o="${std_o}      encryption: aes-gcm-256\n"
	std_o="${std_o}        key: /srv/crypto/zfs.key\n"
	std_o="${std_o}    source: ${spool}/${sdataset}@${ssnapshot}\n"
	std_o="${std_o}      host:    MUH HOST\n"
	std_o="${std_o}      pool: /source\n"
	std_o="${std_o}      dataset:der_set\n"
	std_o="${std_o}      snapshot:   ein_shoot\n"
	std_o="${std_o}      format: 432sfd.,dfs\n"
	std_o="${std_o}    kernel: ${kver}\n"
	std_o="${std_o}    boot: EFI\n"
	std_o="${std_o}      partition:/dev/sda2\n"
	std_o="${std_o}      loader: refind\n"
	std_o="${std_o}      HELP: YOYOMA\n"
	std_o="${std_o}    swap: file\n"
	std_o="${std_o}      location: ${dpool}/swapr\n"
	std_o="${std_o}      format: 'zfs dataset, no CoW'\n"
	std_o="${std_o}    profile: END_OF_LINE\n"
