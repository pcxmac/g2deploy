#!/usr/bin/env bash

# return a pad, given the argument's value (white space)
function yamlPad()
{
	local _length=${1:?}
	printf '%s\n' "$(printf "%*s%s" ${_length})"
}

# get pad length for yaml formatted string...
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
	_yaml="$(printf "${_yaml}" | sed 's/#.*$//')";											# clear out comments
	_yaml="$(printf "${_yaml}" | sed '/^[[:space:]]*$/d')";									# delete empty lines
	_yaml="$(printf "${_yaml}" | sed 's/[^A-Za-z0-9_.:/*-\s ]//g')";						# filter out invalid characters
	_yaml="$(printf "${_yaml}" | sed 's/:[[:space:]]*/:/g;')";								# get rid of space between values, and :
	_yaml="$(printf "${_yaml}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")";	# filter out coloring

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
	printf '%s\n' "${stdYAML#*:}" | sed 's/ //g; s/^-//'; #s/[^:]*:/';
}

# return the number of elements in a yaml path, ie [ root/partition/directory/leaf ]
function yamlPathL()
{
	local _string="${1:?}"

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
	local _next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";

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
			_next="$(yamlOrder ${_path} $((cp+1)))";
	 	} || { 
			match="";
			_next="trivial";
		}

		[[ -n ${match} ]] && 
		{ 
			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); }
			# cv only changes on a match
			cv="$(yamlOrder ${_path} ${cp})";
		}

		 # EXECUTOR
		[[ -n "${match}" && -z ${_next} ]] && { 
			printf '%s\n' "$(yamlValue $line)"
		}

	done < <(printf '%s\n' "${_yaml}")
}

# adds a new node, match = prefix ;; path = 'root/branch/prefix:SPECIFIC/NEWKEY:NEWVALUE' ... ergo, prefix typically should have an associated value.
# path should be checked prior to insertion ... IE, user needs to check for existing node, insert is not responsible for adding another like node.
# inserts right after parent identified. (see above)
function insertKeyValue()
{
	local cp=0
	local tabLength
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local _newKV="${3:?}"
	local pLength="$(yamlPathL $_path)"
	_yaml="$(yamlStd ${_yaml})"
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";
	local _col=${pLength}
	local _comit='false'

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		tabLength="$(( $(yamlPadL ${line})/2 ))"
		[[ $((tabLength)) < $((cp)) ]] && 
		{
			cp="$((tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((tabLength*2))}$(printf '%s\n' "${cv}").*$")";
			next="$(yamlOrder ${_path} $((cp+1)))"
	 	} || { 
			match="";
			next="trivial";
		}
		[[ -n ${match} ]] && 
		{ 
			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); }
			cv="$(yamlOrder ${_path} ${cp})";
		}

		#  # EXECUTOR
		[[ -n "${match}" && -z ${next} ]] && {
			_col=${cp};
			_comit='true';
		} || {
			printf '%s\n' "${line}";
		}

		[[ ${_comit} == 'true' ]] && {
			modLine="${line}";
			printf '%s\n' "${modLine}";
			modLine="$(yamlPad $((tabLength*2+2)))$(printf '%s\n' "${_newKV}" | sed 's/ //g')";
			printf '%s\n' "${modLine}";
			_comit='false'
		}

	done < <(printf '%s\n' "${_yaml}")
}

# remove target branch, and it's children
#	1	if match, silence output
#	2	if cursor < match column, begin output again
#
function removeKeyValue()
{
	local cp=0
	local tabLength
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local pLength="$(yamlPathL $_path)"
	_yaml="$(yamlStd ${_yaml})"
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";
	local _col=${pLength}
	local _omit='false'

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		tabLength="$(( $(yamlPadL ${line})/2 ))"
		[[ $((tabLength)) < $((cp)) ]] && 
		{
			cp="$((tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((tabLength*2))}$(printf '%s\n' "${cv}").*$")";
			next="$(yamlOrder ${_path} $((cp+1)))"
	 	} || { 
			match="";
			next="trivial";
		}
		[[ -n ${match} ]] && 
		{ 
			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); }
			cv="$(yamlOrder ${_path} ${cp})";
		}
		[[ ${_omit} == 'true' && ${cp} == ${tabLength} ]] && { _omit='false'; }

		#  # EXECUTOR
		[[ -n "${match}" && -z ${next} ]] && {
			_col=${cp};
			_omit='true';
		} || {
			[[ ${_omit} == 'false' ]] && { printf '%s\n' "${line}"; }
		}

	done < <(printf '%s\n' "${_yaml}")
}

# finds a [KEY:VALUE] pair in a yaml object, modifies it's [VALUE], and dumps the YAML OBJECT
# modify path = 'root/prefix/KEYVALUE:OLDVALUE:NEWVALUE'
#	1	if match, print modified value
#	2	print if no match
function modifyKeyValue()
{
	local cp=0
	local tabLength
	local _yaml="${1:?}"		# YAML FILE, 2 spaced.
	local _path="${2:?}"
	local _value="${3:?}"
	local pLength="$(yamlPathL $_path)"
	_yaml="$(yamlStd ${_yaml})"
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";
	local _key

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		tabLength="$(( $(yamlPadL ${line})/2 ))"
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
			cv="$(yamlOrder ${_path} ${cp})";
		}

		#  # EXECUTOR
		[[ -n "${match}" && -z ${next} ]] && {
			_key=${cv%%:*}
		 	modLine="$(yamlPad $((tabLength*2)))$(printf '%s:%s\n' "${_key}" "${_value}" | sed 's/ //g')";
			printf '%s\n' "${modLine}";
		} || {
			printf '%s\n' "${line}";
		}

	done < <(printf '%s\n' "${_yaml}")
}

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

