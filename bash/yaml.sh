#!/usr/bin/env bash

# these algorithms are not optimized for speed, or removing redundancy in filtering/standardizing.


# return a pad, given the argument's value (white space) ... probably needs to be superseeded with printf %##s
function yamlPad()
{
	local _length=${1:?}
	[[ ${_length} == 0 ]] && { return; };
	printf '%s\n' "$(printf "%*s%s" ${_length})"
}

# get pad length for yaml formatted string...
function yamlPadL()
{
	local _key_value=${1};
	[[ ${_key_value} == '' ]] && {
		printf '0\n';
	} || {
		_key_value="$(( $(printf '%s\n' ${_key_value} | awk -F '[^ ].*' '{print length($1)}') ))";
		printf '%s\n' "${_key_value}";
	};
}

#	yaml standardization [charcater format/spec] formula
#	yamlStd {PATH|string of source} ,, accepts stdin
#	ex. cat ../config/host.cfg | yamlStd	
#	ex. echo "$_YAML" | yamlStd
#	ex. yamlStd "$_YAML"
#	ex. yamlStd ../config/host.cfg
	
function yamlStd()
{
	local _tab=2
	local _tabLength=0
	local _padLength=""
	local _yaml=""

	#echo "test"

	# option to use string or file
	[[ -p /dev/stdin ]] && {  _yaml="$(cat -)"; ordo="stdin"; } || {  _yaml="${1}"; ordo="parametric"; };
	[[ -f ${_yaml} ]] && { _yaml="$(cat "${_yaml}")"; };

	# empty yaml case
	[[ -z ${_yaml} ]] && { return; };

	#echo "post in"

	# filtration
	_yaml="$(printf "${_yaml}" | sed 's/\t/  /g')";											# convert tabs to spaces tabs by themselves will yield a 0 length tab
	_yaml="$(printf "${_yaml}" | sed 's/#.*$//')";											# clear out comments
	_yaml="$(printf "${_yaml}" | sed '/^[[:space:]]*$/d')";									# delete empty lines
	_yaml="$(printf "${_yaml}" | sed 's/[^A-Za-z0-9_${}.:/*-\s ]//g')";						# filter out invalid characters, valid characters present
	_yaml="$(printf "${_yaml}" | sed 's/:[[:space:]]*/:/g;')";								# get rid of space between values, and :
	_yaml="$(printf "${_yaml}" | sed -e 's/\"//g')";										# filter out quotes
	_yaml="$(printf "${_yaml}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")";	# filter out coloring

	# root node, is assumed to be the first entry, it will have the root offset, this should be zero.
	_tmp="$(sed -n '1p' < <(printf '%s\n' $_yaml))"
	offset="$(printf '%s\n' ${_tmp} | awk -F '[^ ].*' '{print length($1)}')"

	#echo "_tmp = $_tmp"
	#echo "offset = $offset"
	#echo "yaml = $_yaml"

	# determine the spec tab length, it will be changed to/remain two.
	IFS=''
	while read -r line
	do
		_tabLength="$(printf '%s\n' ${line} | awk -F '[^ ].*' '{print length($1)}')"
		[[ -n ${_tabLength} ]] && { break; }; 
	done < <(printf '%s' "${_yaml}" | \grep -iP '^\s.*[A-Za-z0-9]')
	IFS="${_tmp}"

	# rebuild yaml with 2x tabs
	IFS=''
	while read -r line
	do
		# GENERATE
		_padLength="$(printf "${line}" | awk -F '[^ ].*' '{print length($1)}')"
		_padLength="$((_tab*_padLength))";
		#echo "tab length = $_tabLength"
		[[ ${_tabLength} == 0 ]] && { _padLength=0; } || { _padLength="$((_padLength/_tabLength))"; };
		# get rid of preceeding whitespace, \t
		fLine="$(yamlPad $_padLength)$(printf '%s\n' ${line} | sed -e 's/^[ \t]*//')"	
		printf '%s\n' "${fLine}"
	done < <(printf '%s\n' "${_yaml}")
	IFS="${_tmp}"
}

# picks out list items, or values from key-value pairs
function yamlValue()
{
	local _path
	local _stdYAML
	local _param=":"
	_stdYAML="${1:?}"
	_path="${2}"

	# exception, for listed key searching, if, search path ends in '-', its looking for key, not value, thus prune value
	[[ -n ${_path} ]] && { 
		[[ -n "$(printf '%s' "${_path}" | \grep '\-$')"  && -n "$(printf '%s' "${_path%-*}" )" ]] && { _stdYAML="${_stdYAML%%:*}"; };
	};

	# if value is pruned, along with colon, it will just print the key, which is desired, in the above case.
	printf '%s\n' "${_stdYAML#*:}" | sed 's/ //g; s/^-//'; #s/[^:]*:/';
}

# return the number of elements in a yaml path, ie [ root/partition/directory/leaf ]
function yamlPathL()
{
	local _string="$(echo ${1:?} | sed 's,/$,,')"; 
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
#	findKeyValue {PATH|string of source} {search path}
#	ex.	findKeyValue ../config/host.cfg 'server:buildserver/root'
#	ex. findKeyValue "$_YAML" 'server' ,, (for multiple entries @ server/ , will have multiple outputs)
#	ex. cat ../config/host.cfg | findKeyValue 'server:buildserver/root'

function findKeyValue() 
{
	# cursor position
	local cp=0
	# actual number of tabs between key-value and left-most
	local _tabLength
	local ordo;

	# option to use string or file
 	[[ -p /dev/stdin ]] && { _yaml="$(cat - | yamlStd)"; ordo="stdin"; } || { _yaml="${1:?}"; ordo="parametric"; };
 	[[ -f ${_yaml} ]] && { _yaml="$(cat ${_yaml})"; };

	# the path is arg 1, the source is stdin already standardized ...
 	[[ ${ordo} == "stdin" ]] && { _path="${1:?}";  };
	# the path is arg 2, the source is arg 1, standardize ...
 	[[ ${ordo} == "parametric" ]] && { _path="${2:?}"; _yaml="$(yamlStd "${_yaml}")"; };

	# path length, to determine target leaf/node
	local pLength="$(yamlPathL $_path)"

	# strings, about which path is articulated
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local _next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";

	# used to deny incomplete matches, ie, 'repo' !=(match) 'repository'
	local _granular=""


	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		_tabLength="$(( $(yamlPadL ${line})/2 ))"

		# if moving outside the scope of the current cursor
		[[ $_tabLength < $cp ]] && 
		{
			cp="$((_tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((_tabLength)) == $((cp)) ]] && {
		 	
			[[ -n "$(echo ${line} | \grep -i "^\s*-.*")" ]] && {
				# match for :: '-'
				match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((_tabLength*2))}$(printf '%s\n' "-${cv}").*$")";
			} || {
				# match, literally :: 'key' || 'key/' || '-key' || '-key/'
				match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((_tabLength*2))}$(printf '%s\n' "${cv}").*$")";
			};
			_granular="$(echo ${match} | sed 's/^ *//g' | sed 's/^-//g' )";
			[[ ! ${_granular%%:*} == ${cv%%:*} && ${cv%%:*} != '-' ]] && { match=""; };

			_next="$(yamlOrder ${_path} $((cp+1)))";

	 	} || { 
			match="";
			_next="trivial";
		}

		[[ -n ${match} ]] && 
		{ 
			[[ $((cp)) < $((pLength)) ]] && { ((cp++)); };
			# cv only changes on a match
			cv="$(yamlOrder ${_path} ${cp})";
		}

		 # EXECUTOR
		[[ -n "${match}" && -z ${_next} ]] && { 
			printf '%s\n' "$(yamlValue $line $_path)";
		};

	done < <(printf '%s\n' "${_yaml}")
}

#	insertKeyValue {PATH|String of source YAML} {search path} {new key:value}  
#	ex. insertKeyValue ../config/host.cfg 'server:buildserver/root' 'new:value'
#	ex. insertKeyValue "$_YAML" 'server:buildserver/root' 'new:value'
#	ex. echo "$_YAML" | yamlStd | insertKeyValue
#	ex. echo "" | insertKeyValue '.' 'key:value'
#	rule: in case of non-matching search path, use '.' , as this searches for 'all'

# this bitch is slow, thinking bigO^2
function insertKeyValue()
{
	local cp=0
	local ordo;
	local _tabLength;
	local _yaml;			# yaml source
	local _path;			# new path
	local _newKV;			# new key value to insert

	# option to use string or file
 	[[ -p /dev/stdin ]] && { _yaml="$(cat - | yamlStd)"; ordo="stdin"; } || { _yaml="${1}"; ordo="parametric"; };

 	[[ -f ${_yaml} ]] && { _yaml="$(cat ${_yaml})"; };

	# the path is arg 1, the source is stdin already standardized ...
 	[[ ${ordo} == "stdin" ]] && { 
		_path="${1:?}"; 
		_newKV="${2:?}"; 
	};
	# the path is arg 2, the source is arg 1, standardize ...
 	[[ ${ordo} == "parametric" ]] && { 
		_path="${2:?}";
		_newKV="${3:?}";
		_yaml="$(yamlStd "${_yaml}")"; 
	};

	local pLength="$(yamlPathL $_path)"

	#_yaml="$(yamlStd ${_yaml})"

	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";
	local _col=${pLength}
	local _comit='false'

	IFS=''
	# if empty file
	[[ ${_yaml} == '' ]] && { printf '%s\n' "${_newKV}"; return; };
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		_tabLength="$(( $(yamlPadL ${line})/2 ))"
		[[ $((_tabLength)) < $((cp)) ]] && 
		{
			cp="$((_tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((_tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((_tabLength*2))}$(printf '%s\n' "${cv}").*$")";
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
			modLine="$(yamlPad $((_tabLength*2+2)))$(printf '%s\n' "${_newKV}" | sed 's/ //g')";
			printf '%s\n' "${modLine}";
			_comit='false'
		}

	done < <(printf '%s\n' "${_yaml}")
}

#	removeKeyValue {PATH|string of source yaml} {path in yaml, to recursively delete}
#	ex. removeKeyValue ../config/host.cfg 'server:buildserver/host'
#	ex. cat ../config/host.cfg | removeKeyValue 'server:pkgROOT/gcc'
#	ex. echo "$_YAML" | yamlStd | removeKeyValue 'server/profile'

function removeKeyValue()
{
	local cp=0
	local _tabLength
	local _yaml;		# yaml source to filter
	local _path;		# path to remove (recursive implicitly)
	local ordo;

	# option to use string or file
 	[[ -p /dev/stdin ]] && { _yaml="$(cat - | yamlStd)"; ordo="stdin"; } || { _yaml="${1:?}"; ordo="parametric"; };
 	[[ -f ${_yaml} ]] && { _yaml="$(cat ${_yaml})"; };

	#echo "$ordo"

	# the path is arg 1, the source is stdin already standardized ...
 	[[ ${ordo} == "stdin" ]] && { 
		_path="${1:?}"; 
#		_newKV="${2:?}"; 
	};
	# the path is arg 2, the source is arg 1, standardize ...
 	[[ ${ordo} == "parametric" ]] && { 
#		echo "shit"
		_path="${2:?}";
#		_newKV="${3:?}";
		_yaml="$(yamlStd "${_yaml}")"; 
	};

	local pLength="$(yamlPathL $_path)"
	#_yaml="$(yamlStd ${_yaml})"
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";
	local _col=${pLength}
	local _omit='false'

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		_tabLength="$(( $(yamlPadL ${line})/2 ))"
		[[ $((_tabLength)) < $((cp)) ]] && 
		{
			cp="$((_tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((_tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((_tabLength*2))}$(printf '%s\n' "${cv}").*$")";
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
		[[ ${_omit} == 'true' && ${cp} == ${_tabLength} ]] && { _omit='false'; }

		#  # EXECUTOR
		[[ -n "${match}" && -z ${next} ]] && {
			_col=${cp};
			_omit='true';
		} || {
			[[ ${_omit} == 'false' ]] && { printf '%s\n' "${line}"; }
		}

	done < <(printf '%s\n' "${_yaml}")
}

# 	modifyKeyValue {PATH|string of source yaml} {path in yaml} {modification string}
# 	modification string = 'root/prefix/KEYNAME:OLDVALUE:NEWVALUE'
#	ex. echo "$YAML" | yamlStd | modifyKeyValue 'server' 'calvin' => ^server:calvin
#	ex. cat ../config/host.cfg | modifyKeyValue 'server:pkgROOT/friends/host:jupiter.hypokrites.net' 'jupiter2.hypokrites.net'
#	ex. modifyKeyValue ../config/host.cfg 'server:buildserver/host' 'bigJohn.com'

function modifyKeyValue()
{
	local cp=0
	local _tabLength
	local _yaml;		# reference to yaml source
	local _path;		# yaml path to operate on (if not specific enough, multiple lines can be mangled)
	local _value;		# new value (TOBE)
	local _key;			# used in the exectutor to switch the key-value 
	local modLine;		# the mangled yaml string

	# option to use string or file
 	[[ -p /dev/stdin ]] && { _yaml="$(cat - | yamlStd)"; ordo="stdin"; } || { _yaml="${1:?}"; ordo="parametric"; };
 	[[ -f ${_yaml} ]] && { _yaml="$(cat ${_yaml})"; };

	# the path is arg 1, the source is stdin already standardized ...
 	[[ ${ordo} == "stdin" ]] && { 
		_path="${1:?}"; 
		_value="${2:?}"; 
	};
	# the path is arg 2, the source is arg 1, standardize ...
 	[[ ${ordo} == "parametric" ]] && { 
		_path="${2:?}";
		_value="${3:?}";
		_yaml="$(yamlStd "${_yaml}")"; 
	};

	local pLength="$(yamlPathL $_path)"
	#_yaml="$(yamlStd ${_yaml})"
	local cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
	local next="$(printf '%s\n' $(yamlOrder "${_path}" $((cp+1))))";

	IFS=''
	# pWave constructor
	while read -r line
	do
		# GENERATOR
		_tabLength="$(( $(yamlPadL ${line})/2 ))"
		[[ $((_tabLength)) < $((cp)) ]] && 
		{
			cp="$((_tabLength))";
			cv="$(printf '%s\n' $(yamlOrder "${_path}" ${cp}))";
		}

		# DETERMINANAT
		[[ $((_tabLength)) == $((cp)) ]] && {
		 	match="$(printf '%s\n' "${line}" | \grep -wP "^\s{$((_tabLength*2))}$(printf '%s\n' "${cv}").*$")";
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
		 	modLine="$(yamlPad $((_tabLength*2)))$(printf '%s:%s\n' "${_key}" "${_value}" | sed 's/ //g')";
			printf '%s\n' "${modLine}";
		} || {
			printf '%s\n' "${line}";
		}

	done < <(printf '%s\n' "${_yaml}")
}


# TEST PROCEDURES ... if './yaml.sh --test'