#!/usr/bin/env bash

# path format = key:value/next_key:next_value/.../last_key:last_value
# this functino outputs the key:value for a given 'column' or order coordinate,
# example : yamlOrder 'path/to:value/get:not/is/hidden' 2 = { 'to:value' 'get:not/is/hidden'}
# ie, you get the key/value combination, and the remainder of the path in the right most return value

# subprocesses do not respect variable case !!!

function yamlTabL()
{
	local _yaml="${1:?}"							# YAML FILE, X spaced.
	local tabLength=""
	# option to use string or file
	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

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

function yamlLength()
{
	local _string="${1:?}"
    local count=1
    while [ ${_string} != ${_string#*/} ]
    do
        count=$((count+1))
		_string="${_string#*/}"
	done
	echo "${count}"  # print length of address
}

# [cursor] : [remainder] : [current path]
function yamlOrder() 
{

	local _string="${1:?}"
	local _order="${2:?}"
	local _match=""

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
	echo -e "[${_match}]\t[${_string}]\t[${_prior}]"                 # returns sought after key/value + remaining search pattern
	#echo -e "${_match}\t${_string}"                 # returns sought after key/value + remaining search pattern
}


function findKeyValue() 
{
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local tabL="$(yamlTabL "${_yaml}")"
	local cp=1
	local listing="false"
	local cv="$(yamlOrder "${_path}" ${cp})"
	local ws=$(( tabL*(${cp}-1) ))
	
	# option to use string or file
 	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	# positive logic loop
	IFS=''
	while read -r line
	do
		match="$(echo ${line} | \grep -P "$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
		#echo "[$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')] /$cp/ >$match< $line > $(echo $cv | awk '{print $1}')"
		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"

		[[ -z "${rem}" && -n "${match}" ]] &&
		{
			if [[ ${match#*:} == ${match} ]]
			then
				echo "${match#*-}" | sed 's/^[ \t]*//';
			else
				echo "${match#*:}" | sed 's/^[ \t]*//';
			fi			 
			listing="true"; 
		}
		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
		[[ -z "${match}" && ${listing} == "true" ]] && { break; }

		ws=$(( tabL*(${cp}-1) ))
	done < <(echo -e "${_yaml}")
}

function insertKeyValue() 
{

	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local tabL="$(yamlTabL "${_yaml}")"
	local cp=1
	local listing="false"
	local cv="$(yamlOrder "${_path}" ${cp})"
	local ws=$(( tabL*(${cp}-1) ))
	
	# option to use string or file
 	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	# positive logic loop
	IFS=''
	while read -r line
	do
		tabLength="$(($(echo ${line} | awk -F '[^ ].*' '{print length($1)}')/2 +1))"
		match="$(echo ${line} | \grep -P "$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')"     )"
		rem="$(echo ${cv} | awk '{print $2}' | sed 's/[][]//g')"

		echo "${rem} :: ${match}"

		[[ -z "${rem}" && -n "${match}" ]] &&
		{
			echo "root dir !"
			listing="true";
			((cp+=1))
		}
		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp}    )"; }
		[[ -z "${match}" && ${listing} == "true" && ${tabLength} < "${cp}" ]] && { listing="done"; }

		if [[ ${listing} == "done" ]]
		then
			if [[ ${match#*:} == ${match} ]]
			then
				echo "INSERT THIS" | sed 's/^[ \t]*//';
			else
				echo "INSERT THIS" | sed 's/^[ \t]*//';
			fi			 
		fi

		ws=$(( tabL*(${cp}-1) ))

		echo "${listing} ${line}"
		#echo "[$(echo ${cv} | awk '{print $1}' | sed 's/[][]//g' | sed 's/ //g')] /$cp/ >$match< {$tabLength} $line > $(echo $cv | awk '{print $1}') :: $line"
		#echo $line

	done < <(echo -e "${_yaml}")
}


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
	std_o="${std_o}    pool: ${spool}\n"
	std_o="${std_o}    dataset: ${sdataset}\n"
	std_o="${std_o}    snapshot: ${ssnapshot}\n"
	std_o="${std_o}    format: ${stype}\n"
	std_o="${std_o}  kernel: ${kver}\n"
	std_o="${std_o}  boot: EFI\n"
	std_o="${std_o}    partition:/dev/sda2\n"
	std_o="${std_o}    loader: refind\n"
	std_o="${std_o}    HELP: YOYOMA\n"
	std_o="${std_o}  swap: file\n"
	std_o="${std_o}    location: ${dpool}/swap\n"
	std_o="${std_o}    format: 'zfs dataset, no CoW'\n"
	std_o="${std_o}  profile: END_OF_LINE\n"

