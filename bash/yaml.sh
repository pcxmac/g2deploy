#!/usr/bin/env bash

# path format = key:value/next_key:next_value/.../last_key:last_value
# this functino outputs the key:value for a given 'column' or order coordinate,
# example : yamlOrder 'path/to:value/get:not/is/hidden' 2 = { 'to:value' 'get:not/is/hidden'}
# ie, you get the key/value combination, and the remainder of the path in the right most return value

# subprocesses do not respect variable case !!!

function yamlTabL()
{
	local _yaml="${1:?}"							# YAML FILE, 2 spaced.
	local tabLength=""
	# option to use string or file
	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	_tmp="${IFS}"
	IFS=''
	while read -r line
	do
		tabLength="$(echo ${line} | awk -F '[^ ].*' '{print length($1)}')"
		if [[ -n ${tabLength} ]]; then break; fi 

	done < <(echo ${_yaml} | \grep -iP '^\s.*[a-z]')
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
	echo "${_match}	${_string}"                 # returns sought after key/value + remaining search pattern
}

# yaml -f find, -r remove, -a add, -p (print)

# allows heirarchys of depth=N (YAML FORMAT)
function findKeyValue() 
{
	local _yaml="${1:?}"						# YAML FILE, 
	local _path="${2:?}"						# path to search for, includes key in rightmost
	local tabL=$(yamlTabL ${_yaml})				# tab format, support for autodetect
	local cp=1									# search column, cp = 1 = first column
	local listing="false"						# not currently matching the prefix (prior to right most)
	local cv="$(yamlOrder "${_path}" ${cp})"		
	local ws=$(( tabL*(${cp}-1) ))				
	local remainder
	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

	_tmp="${IFS}"
	IFS=''
	while read -r line
	do
		match="$(echo ${line} | \grep -P "^\s{$ws}$(echo ${cv} | awk '{print $1}')" | sed 's/ //g')"
		remainder="$(echo ${cv} | awk '{print $2}')"
		[[ -z "${remainder}" && -n "${match}" ]] && { echo "${match#*:}"; listing="true"; }
		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp})"; }
		[[ -z "${match}" && ${listing} == "true" ]] && { break; }
		ws=$(( tabL*(${cp}-1) ))
	done < <(echo ${_yaml})
	IFS="${_tmp}"
}

# outputs a modified yaml string, which can be directed by the user to replace a file or string (-i, insert) (-r, remove)
# function modifyKeyValue() 
# {

# 	local _yaml="${1:?}"						# YAML FILE, 
# 	local _path="${2:?}"						# path to search for, includes key in rightmost
# 	local _mode="${3:?}"						# -i or -r supported
# 	local tabL=$(yamlTabL ${_yaml})				# autodetects tab space and assigns here
# 	local cp=1									# search column, cp = 1 = first column
# 	local listing="false"						# not currently matching the prefix (prior to right most)
# 	local cv="$(yamlOrder "${_path}" ${cp})"		
# 	local ws=$(( tabL*(${cp}-1) ))				
# 	local rem 									

# 	local target=""								# -i, target = last key-value, -r, target = whole path/key-value

# 	orderLength="$(yamlLength "${_path}")"
# 	if [[ ${_mode} == "-i" ]]; then target="$(yamlOrder ${_path} $((orderLength-1)) | awk '{print $1}')"; fi
# 	if [[ ${_mode} == "-r" ]]; then target=${_path};fi

# 	# if inserting, we will be matching length-1, and the rightmost will be a true key value pair - ///key:value
# 	# if inserting, the last value follows after the last :, in case of values like /dev/sdX, : is the control character
# 	# if removing, do not provide value, generally speaking, just provide the last key, and the last /, will decide

# 	echo ${target}
# 	sleep 30
	
# 	# option to use string or file
# 	[[ -f ${_yaml} ]] && _yaml="$(cat ${_yaml})"

# 	# positive logic loop
# 	_tmp="${IFS}"
# 	IFS=''
# 	while read -r line
# 	do
# 		match="$(echo ${line} | \grep -P "^\s{$ws}$(echo ${cv} | awk '{print $1}')" | sed 's/ //g')"
# 		rem="$(echo ${cv} | awk '{print $2}')"

# 		# used for removal of key-value pair

# 		[[ -z "${rem}" && -n "${match}" ]] && { listing="true"; }



# 		# if a match is found, advance.		[[ YES MATCH ]]
# 		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${_path}" ${cp})"; }
# 		# if correct path, key found, & not matching any more time to break, 
# 		# 'success ?' has echo'd ALL the match(s),
# 		[[ -z "${match}" && ${listing} == "true" ]] && { echo "INSERT HERE" }
# 		ws=$(( tabL*(${cp}-1) ))
# 	done < <(echo ${_yaml})
# 	IFS="${_tmp}"
# }
    # test yaml string for debug

	std_o="# Install Config for @ ${dhost}:123456\n"
	std_o="${std_o}install: ${dpool}/${ddataset}\n"
	std_o="${std_o}  disks: \n"
	std_o="${std_o}    - ${disk}${pmod}3\n"
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
	std_o="${std_o}  swap: file\n"
	std_o="${std_o}    location: ${dpool}/swap\n"
	std_o="${std_o}    format: 'zfs dataset, no CoW'\n"
	std_o="${std_o}  profile: ${sprofile}\n"

