#!/usr/bin/env bash

# path format = key:value/next_key:next_value/.../last_key:last_value
# this functino outputs the key:value for a given 'column' or order coordinate,
# example : yamlOrder 'path/to:value/get:not/is/hidden' 2 = { 'to:value' 'get:not/is/hidden'}
# ie, you get the key/value combination, and the remainder of the path in the right most return value

# subprocesses do not respect variable case !!!

# no syntax checking present

##################################################################################################################################

# yaml standardization [charcater format/spec] formula
function yamlStd()
{
	local _yaml="${1:?}"
	echo -e "${_yaml}" | sed 's/#.*$//' | sed '/^[[:space:]]*$/d' | sed 's/[^A-Za-z0-9_.:/*-\s ]//g'
}

# scans a yaml structure, and returns the first length of a tab occurance, yaml tab values are typically 2 and 4
function yamlTabL()
{
	local _yaml="${1:?}"							# YAML FILE, X spaced.
	local tabLength=""
	# option to use string or file
	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	_yaml="$(yamlStd ${_yaml})"

	_tmp="${IFS}"
	IFS=''
	while read -r line
	do
		#echo ${line}
		tabLength="$(echo ${line} | awk -F '[^ ].*' '{print length($1)}')"
		if [[ -n ${tabLength} ]]; then break; fi 

	done < <(echo -e "${_yaml}" | \grep -iP '^\s.*[a-z]')
	IFS="${_tmp}"
	echo $tabLength
}

# return the number of elements in a yaml path, ie [ root/partition/directory/leaf ]
function yamlLength()
{
	local _string="${1:?}"

	_string="$(yamlStd ${_string})"

    local count=1
    while [ ${_string} != ${_string#*/} ]
    do
        count=$((count+1))
		_string="${_string#*/}"
	done
	echo "${count}"  # print length of address
}

# [cursor] : [remainder] : [current path]
function yamlPath() 
{
	# last slash added to ensure conditional statement inside for loop terminates when last two keys are the same, ie. ../disk/disk
	local _string="${1:?}/"
	local _order="${2:?}"
	local _match=""

	_string="$(yamlStd ${_string})"

	for ((i=1;i<=${_order};i++))
	do
		_match="${_string%%/*}"
		_string="${_string#*/}"
		if [[ ${_match} == "${_string}" ]]
		then
			_string=""
			break;
		fi
	done
	_prior="${1%/${_string}*}"
	# returns sought after key/value + remaining search pattern. There should be no white space between or after key-value pairs.
	echo -e "[${_match}]\t[${_string}]\t[${_prior}]" | sed 's/ //g' | sed 's:/*$::';                  
	#echo -e "${_match}\t${_string}"                 # returns sought after key/value + remaining search pattern
}

function yamlOrder()
{
	# last slash added to ensure conditional statement inside for loop terminates when last two keys are the same, ie. ../disk/disk
	local _string="${1:?}/"
	local _order="${2:?}"
	local _match=""

	_string="$(yamlStd ${_string})"

	for ((i=1;i<=${_order};i++))
	do
		_match="${_string%%/*}"
		_string="${_string#*/}"
		if [[ ${_match} == "${_string}" ]]
		then
			_string=""
			break;
		fi
	done
	
	# returns sought after key/value + remaining search pattern
	echo -e "${_match}" | sed 's/ //g' | sed 's:/*$::'               
}

# return a pad, given the argument's value (white space)
function yamlTab() 
{
	local _length=${1:?}
	echo "$( printf "%*s%s" ${_length} )"
}

# find a value in a yaml structure, keys can have their values present for selecting the right branches, with in heirarchys with like named keys
# not all key-value pairs have to be explicit, only those which are unique to the path, but which need to differentiate are required.
function findKeyValue() 
{
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local tabL="$(yamlTabL "${_yaml}")"
	local listing="false"
	# cursor position
	local cp=1
	# string, about which path is articulated
	local cv="$(echo $(yamlOrder "${_path}" ${cp}))";
	# actual number of tabs between key-value and left-most
	local tabLength
	#local cursor="$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g')";

	#echo $_path
	#echo $cv

	# option to use string or file
 	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	#echo $tabL

	# positive logic loop
	IFS=''
	while read -r line
	do
		# get order of key, ie how many tabs are in between key and left-most
		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}')/2 +1))"
		# if tabLength is less than the cursor, reset cursor (cv), the position assumes =tabLength

		#echo "[${tabLength} : $((cp*tabL))]" 

		#echo "tab length = $tabLength ; cp = $cp"

		[[ ${tabLength} < "$((cp*tabL))" ]] && 
		{ 
			listing="false";
			cp="$((tabLength))";
			cv="$(echo $(yamlOrder "${_path}" ${cp}))";
		}

		sleep 0

		# format the line to have the correct tabLength and no whitespace in between key-value pairs.
		line="$(yamlTab $((tabL * tabLength)))$(echo ${line} | sed 's/ //g')"
	 	#cursor="$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g')";

		#echo "$line :: $(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"
		[[ $cv != "" ]] && match="$(echo ${line} | \grep -wP "^\s{$((cp*tabL))}$(echo ${cv}).*$")";

		#echo "\grep -wP "^\s{$((cp*tabL))}$(echo ${cv})$""

		#echo "<${tabLength}>[$cp] > <$line> ($match) [$cv]"
		echo "$line ++$match++"
		#echo "$(yamlOrder "${_path}" ${cp}) [${tabLength}|${cp}]${line} < $match | $rem /${listing}"
		#rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"
#sleep 5
		#echo $line
		# if there is a match, and it's not listing, and the next path element doesn't exist ...
		[[ -n "${match}" && ${listing} == "false" ]] && [[ "$(yamlOrder "${_path}" $((cp+1)))" != "" ]] &&
		{ 
			((cp+=1));
			cv="$(echo $(yamlOrder "${_path}" ${cp}))";
			#echo "ADD CP @ $cp"
		}

		[[ -z "${rem}" && -n "${match}" ]] && [[ ${listing} == "false" ]] 
		{
			[[ ${match#*:} == ${match} ]] &&
		 	{
		 		#echo "---${match#*-}--- ---${rem}--- && ${match} && ${listing} == false $cv" | sed 's/^[ \t]*//';
		 	} || {
		 		#echo ":::${match#*:}::: :::${rem}::: && ${match} && ${listing} == false $cv" | sed 's/^[ \t]*//';
		 	}			 
		 	listing="true"; 
		}

		# if no longer matching, whether listing or scanning, advance cursor, disable listing
		# [[ -z "${match}" ]] && 
		# { 
		# 	# cursor forward in the path
		# 	cursor="$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g')";
		# 	cp=$((cp+1));
		# 	cv="$(yamlOrder "${_path}" ${cp})"; 
		# 	listing="false"
		# }
		
		[[ -z "${match}" && ${listing} == "true" ]] && { listing="done"; }
		
		#echo "[${tabLength},$((cp*tabL))]$line :: ${cursor},${listing} :: ${match}"

	#echo "[${tabLength}|${cs}]$line < $match | $rem "
	# format the length to omit comments & empty lines, and filter out non-spec characters
	done < <(yamlStd "${_yaml}")
}



















































# add a key-value pair as the last child, under the guardianship of the prefix path, ie [root/partition/path/prefix/ KEY:VALUE]
# checks for existing KEY:VALUE, same keys can exist with in a prefix/parent branch
function insertKeyValue() 
{
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local tabL="$(yamlTabL "${_yaml}")"
	local cp=1
	local listing="false"
	local cv="$(yamlOrder "${_path}" ${cp})"
	local cs=$(( tabL*(${cp}-1) ))
	
	if [[ -n $(findKeyValue ${_yaml} ${_path}) ]] && { echo "-------------------------------------found"; } 

	# option to use string or file
 	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	# positive logic loop
	IFS=''
	while read -r line
	do

		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}') ))"
		match="$(echo ${line} | \grep -P "^\s{$cs}$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"

		if [[ ${tabLength} < ${cs} ]] && { echo "SHIT !"; listing="false"; }
		[[ -z "${rem}" && -n "${match}" ]] &&
		{
			#echo "----------------LIMIT"
			# if [[ ${match#*:} == ${match} ]]
			# then
			# 	echo "${match#*-}" | sed 's/^[ \t]*//';
			# else
			# 	echo "${match#*:}" | sed 's/^[ \t]*//';
			# fi			 
			listing="true"; 
		}
		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
		[[ -z "${match}" && ${listing} == "true" ]] && { listing="false"; echo "[${tabLength}|${cs}]$(yamlTab $((tabLength)))<><>NEW CHILD<><>"; }

		echo "[${tabLength}|${cs}]$line"

		cs=$(( tabL*(${cp}-1) ))
	done < <(echo -e "${_yaml}")
}

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
	std_o="${std_o}install: ${dpool}/${ddataset}\n"
	std_o="${std_o}  disks: ZORO\n"
	std_o="${std_o}    - /dev/sda3\n"
	std_o="${std_o}    - /dev/sdb3\n"
	std_o="${std_o}    - /dev/sdc3\n"
	std_o="${std_o}    - /dev/sdd3\n"
	std_o="${std_o}    pool: ${dpool}\n"
	std_o="${std_o}    dataset: ${ddataset}\n"
	std_o="${std_o}    path: ${dpath}\n"
	std_o="${std_o}    format: zfs\n"
	std_o="${std_o}    compression: lz4\n"
	std_o="${std_o}    encryption: aes-gcm-256\n"
	std_o="${std_o}      key: /srv/crypto/zfs.key\n"
	std_o="${std_o}  source: ${spool}/${sdataset}@${ssnapshot}\n"
	std_o="${std_o}    host: ${shost}\n"
	std_o="${std_o}    pool: /source\n"
	std_o="${std_o}    dataset: ${sdataset}\n"
	std_o="${std_o}    snapshot: ${ssnapshot}\n"
	std_o="${std_o}    format: ${stype}\n"
	std_o="${std_o}  kernel: ${kver}\n"
	std_o="${std_o}  boot: EFI\n"
	std_o="${std_o}    partition:/dev/sda2\n"
	std_o="${std_o}    loader: refind\n"
	std_o="${std_o}    HELP: YOYOMA\n"
	std_o="${std_o}  swap: file\n"
	std_o="${std_o}    location: ${dpool}/swapr\n"
	std_o="${std_o}    format: 'zfs dataset, no CoW'\n"
	std_o="${std_o}  profile: END_OF_LINE\n"

