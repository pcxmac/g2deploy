#!/bin/bash

source ${SCRIPT_DIR}/bash/mget.sh

tStamp() 
{
	echo "0x$(echo "obase=16; $(date +%s)" | bc)"
}

function patchSystem()	
{

    local profile="${1:?}"
	local type="${2:?}"
	#local Purl="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${profile}.patches" | sed 's/ //g')"
	#local Curl="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common.patches" | sed 's/ //g')"
	case ${type,,} in
		deploy*)
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common.patches" | sed 's/ //g')" --silent | sed '/^#/d'
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${profile}.patches" | sed 's/ //g')" --silent | sed '/^#/d'
		;;
		services)
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common.services" | sed 's/ //g')" --silent | sed '/^#/d'
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${profile}.services" | sed 's/ //g')" --silent | sed '/^#/d'
		;;
		update)
				# ${profile}.update
				echo "echo '...';"
		;;
		fix=*)
				# ${profile}.fix-0xXXXXXXXX (hex)
				echo "echo '...';"
		;;
	esac
}

function patchFiles_portage() 
{

    local offset="${1:?}"
	local _profile="${2:?}"

	common_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common" | sed 's/ //g' | sed "s/\"/'/g")"
	spec_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${_profile}" | sed 's/ //g' | sed "s/\"/'/g")"

	if [[ -d ${offset}/etc/portage/package.license ]];then rm "${offset}/etc/portage/package.license" -R; fi
	if [[ -d ${offset}/etc/portage/package.use ]];then rm "${offset}/etc/portage/package.use" -R; fi
	if [[ -d ${offset}/etc/portage/package.mask ]];then rm  "${offset}/etc/portage/package.mask" -R;fi
	if [[ -d ${offset}/etc/portage/package.accept_keywords ]];then rm "${offset}/etc/portage/package.accept_keywords" -R;fi
	
	echo -e "$(mget ${common_URI}.uses)\n$(mget ${spec_URI}.uses)" > ${offset}/etc/portage/package.use
	echo -e "$(mget ${common_URI}.keys)\n$(mget ${spec_URI}.keys)" > ${offset}/etc/portage/package.accept_keywords
	echo -e "$(mget ${common_URI}.mask)\n$(mget ${spec_URI}.mask)" > ${offset}/etc/portage/package.mask
	echo -e "$(mget ${common_URI}.license)\n$(mget ${spec_URI}.license)" > ${offset}/etc/portage/package.license

	sed -i "/MAKEOPTS/c MAKEOPTS=\"-j$(nproc)\"" ${offset}/etc/portage/make.conf

	while read -r line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" "${offset}/etc/portage/make.conf"
		fi
	done < <(curl "${common_URI}.conf" --silent)

	while read -r line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" "${offset}/etc/portage/make.conf"
		fi
	done < <(curl "${spec_URI}.conf" --silent)
}

function patchFiles_user() 
{
    local offset="${1:?}"
	local _profile="${2:?}"
	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"	
	mget "${psrc}/root/" "${offset}/root/" 
	mget "${psrc}/home/" "${offset}/home/" 
}

function patchFiles_sys() 
{
    local offset="${1:?}"
	local _profile="${2:?}"

	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"	

	mget "${psrc}/etc/" "${offset}/etc/" 
	mget "${psrc}/var/" "${offset}/var/" 
	mget "${psrc}/usr/" "${offset}/usr/"
	mget "${psrc}/*.[!.]*" "${offset}/"
}

function editboot() 
{

	local VERSION="${1:?}"
	local DATASET="${2:?}"
	local offset="${3:?}/boot"
	local POOL="${DATASET%/*}"
	local UUID="$(blkid | grep "LABEL=\"$POOL\"" | awk '{print $3}' | tr -d '"' | uniq)"
	local line_number=$(grep -n "ZFS=${DATASET} " "${offset}/EFI/boot/refind.conf" | cut -f1 -d:)
	local menuL
	local loadL
	local initrdL

	sed -i "/default_selection/c default_selection ${DATASET}" "${offset}/EFI/boot/refind.conf"

	if [[ -n "${line_number}" ]]
	then
		menuL="$((line_number-5))"
		loadL="$((line_number-2))"
		initrdL="$((line_number-1))"
		sed -i "${menuL}s|menuentry.*|menuentry \"Gentoo Linux ${VERSION} ${DATASET}\" |" ${offset}/EFI/boot/refind.conf
		sed -i "${loadL}s|loader.*|loader \\/linux\\/${VERSION}\\/vmlinuz|" ${offset}/EFI/boot/refind.conf
		sed -i "${initrdL}s|initrd.*|initrd \\/linux\\/${VERSION}\\/initramfs|" ${offset}/EFI/boot/refind.conf
	else
		echo " " >> "${offset}/EFI/boot/refind.conf"
		echo "menuentry \"Gentoo Linux $VERSION $DATASET\"" >> "${offset}/EFI/boot/refind.conf"
		echo '{' >> "${offset}/EFI/boot/refind.conf"
		echo '	icon /EFI/boot/icons/os_gentoo.png' >> "${offset}/EFI/boot/refind.conf"
		echo "	loader /linux/${VERSION#*linux-}/vmlinuz" >> "${offset}/EFI/boot/refind.conf"
		echo "	initrd /linux/${VERSION#*linux-}/initramfs" >> "${offset}/EFI/boot/refind.conf"
		echo "	options \"$UUID dozfs real_root=ZFS=$DATASET default scandelay=2 rw\"" >> "${offset}/EFI/boot/refind.conf"
		echo '	#disabled' >> "${offset}/EFI/boot/refind.conf"
		echo '}' >> "${offset}/EFI/boot/refind.conf"
	fi
}

function clear_mounts()
{
	local offset
	local procs
    local dir	
	local output

	offset="$(echo "$1" | sed 's:/*$::')"
	procs="$(lsof "${offset}" 2>/dev/null | sed '1d' | awk '{print $2}' | uniq)" 
    dir="$(echo "${offset}" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir" | wc -l)"

	if [[ -z ${offset} ]];then exit; fi	# this will break the local machine if it attempts to unmount nothing.

	for process in ${procs}; do kill -9 "${process}"; done

	if [[ -n "$(echo "${dir}" | grep '/dev/')" ]]
	then
		dir="${dir}"
	else
		dir="${dir}\/"
	fi

	while [[ "$output" != 0 ]]
	do
		while read -r mountpoint
		do
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}

function mounts()
{
	local offset="${1:?}"
	local mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"

	echo "msize = $mSize"
	mount -t proc proc "${offset}/proc"
	mount --rbind /sys "${offset}/sys"
	mount --make-rslave "${offset}/sys"
	mount --rbind /dev "${offset}/dev"
	mount --make-rslave "${offset}/dev"

	mount -t tmpfs -o size=$mSize tmpfs "${offset}/tmp"
	mount -t tmpfs tmpfs "${offset}/var/tmp"
	mount -t tmpfs tmpfs "${offset}/run"
	echo "attempting to mount binpkgs..."  2>&1

	mount --bind /var/lib/portage/binpkgs "${offset}/var/lib/portage/binpkgs"

}

function pkgProcessor()
{
    local profile="${1:?}"
	local offset="${2:?}"
	local diffPkgs=""
	local iBase=""
	local allPkgs=""

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url --silent)"
	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url --silent)"
	allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	if [[ ${offset} == "/" ]]
	then
		iBase="$(/usr/bin/qlist -I)"
	else
		iBase="$(chroot "${offset}" /usr/bin/qlist -I)"
	fi

	iBase="$(echo "${iBase}" | uniq | sort)"

	diffPkgs="$(awk 'FNR==NR {a[$0]++; next} !($0 in a)' <(echo "${iBase}") <(echo "${allPkgs}"))"
	echo "${diffPkgs}" | sed '/^#/d' | sed '/^$/d'
}


function install_modules()
{
	local offset="${1:?}"
	local kver="$(getKVER)"
	local ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/kernel ftp)"

	kver="${kver#*linux-}"

	mget "${ksrc}${kver}/" "${offset}/boot/LINUX/"

	mget "${ksrc}${kver}/modules.tar.gz" "${offset}/"
	echo "decompressing ${ksrc}${kver}" 2>&1
	pv "${offset}/modules.tar.gz" | tar xzf - -C "${offset}/"
	rm "${offset}/modules.tar.gz"	
}

function getKVER() 
{
	local url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/kernel" ftp)"
	local kver="$(curl "$url_kernel" --silent | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep "\-gentoo")"
	kver="linux-${kver}"
	echo "${kver}"
}

function decompress() 
{
	local src="${1:?}"
	local dst="${2:?}"
	local compression_type="$(file "${src}" | awk '{print $2}')"
	case $compression_type in
	'XZ')
		pv "${src}" | tar xJf - -C "${dst}"
		;;	
	'gzip')
		pv "${src}" | tar xzf - -C "${dst}"
		;;
	esac
}

function getG2Profile() 
{

	local _mountpoint="${1:?}"
	local _profile=""
	local result=""

	if [[ -n "$(stat "${_mountpoint}" 2>/dev/null)" && -d "${_mountpoint}" ]]
	then
		if [[ ${_mountpoint} == "/" ]]
		then
			result="$(/usr/bin/eselect profile show | tail -n1)"
		else
			result="$(chroot "${_mountpoint}" /usr/bin/eselect profile show | tail -n1)"
		fi
	else
		if [[ -z ${_mountpoint} ]]		# if no mountpoint, implied to use local machine, else result is already defined
		then
			result="$(/usr/bin/eselect profile show | tail -n1)"
		else
			result="${1:?}"
		fi
	fi

	result="${result#*.[0-9]/}"
	result="$(echo "${result}" | sed -e 's/^[ \t]*//' | sed -e 's/\ *$//g')"

	case "${result}" in
        hardened)		    					_profile="17.1/hardened "
        ;;
        default/linux/amd64/17.1 | openrc)		_profile="17.1/openrc"
        ;;
        systemd)								_profile="17.1/systemd "
        ;;
        *plasma)     							_profile="17.1/desktop/plasma "
        ;;
        *gnome)									_profile="17.1/desktop/gnome "
        ;;
        selinux)          						_profile="17.1/selinux "
        ;;
        *plasma/systemd)   						_profile="17.1/desktop/plasma/systemd "
        ;;
        *gnome/systemd)							_profile="17.1/desktop/gnome/systemd "
        ;;
        hardened/selinux) 						_profile="17.1/hardened/selinux "
        ;;
		*)										_profile=""
		;;
    esac

	echo "${_profile}" 
}

function getHostZPool () 
{
	local pool="$(mount | grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo "${pool}"
}

function getZFSMountPoint ()
{
	local dataset="${1:?}"
	local mountpt="$(zfs get mountpoint "${dataset}" 2>/dev/null | sed -n 2p | awk '{print $3}')"
	if [[ -n ${mountpt} ]]; then echo "$(echo ${mountpt} | sed 's:/*$::')"; fi
}

function compress() 
{
	local src="${1:?}"
	local dst="${2:?}"
	local ksize="$(du -sb "$src" | awk '{print $1}')"
	echo "ksize = $ksize"
	tar cfz - "${src}" | pv -s "${ksize}"  > "${dst}"
}

function compress_list() 
{
	local src="${1:?}"
	local dst="${2:?}"
	
	tar cfz - -T "${src}" | (pv -p --timer --rate --bytes > "${dst}")
}

function rSync() 
{
	local src="${1:?}"
	local dst="${2:?}"

	echo "rsync from ${src} to ${dst}"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 "${src}" "${dst}"
}

function zfs_keys() 
{

	local dataset="${1:?}"
	local offset="$(zfs get mountpoint "${dataset}" 2>&1 | sed -n 2p | awk '{print $3}')"
	local format
	local location
	local location_type
	local _source

	local pools="${dataset}"
	pools="${pools%/*}"
	
	for i in ${pools}
	do
		listing="$(zfs list | grep "${i}/" | awk '{print $1}')"

		for j in ${listing}
		do
			dSet="${j}"
			if [ "${dSet}" == '-' ]
			then
				format="N/A"
				location="N/A"
				else
				format="$(zfs get keyformat "${dSet}" | awk '{print $3}' | sed -n '2 p')"
				location="$(zfs get keylocation "${dSet}" | awk '{print $3}' | sed -n '2 p')"
			fi
			if [ "${format}" == 'raw' ] || [ "${format}" == 'hex' ]
			then
				location_type="${location%:///*}"
				if [ "${location_type}" == 'file' ]
				then
					_source="${location#*//}"
					destination="${_source%/*}"
					destination="${offset}${destination}"
					mkdir -p "${destination}"
					if test -f "${_source}"; then
						cp "${_source}" "${destination}"
					fi
				fi
			fi
		done
	done
}

# path format = key:value/next_key:next_value/.../last_key:last_value
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
	echo "${_match}	${_string}"
}

# allows heirarchys of depth=N (YAML FORMAT)
function findKeyValue() 
{

	local yaml="${1:?}"		# YAML FILE, 2 spaced.
	local path="${2:?}"			
	local tabL=2
	local cp=1
	local listing="false"
	local cv="$(yamlOrder "${path}" ${cp})"	
	local ws=$(( tabL*(${cp}-1) ))

	# option to use string or file
	[[ -f ${yaml} ]] && yaml="$(cat ${yaml})"

	# positive logic loop
	_tmp="${IFS}"
	IFS=''
	while read -r line
	do
		match="$(echo ${line} | grep -P "^\s{$ws}$(echo ${cv} | awk {'print $1'})" | sed 's/ //g')"
		rem="$(echo ${cv} | awk {'print $2'})"
		# success ?
		[[ -z "${rem}" && -n "${match}" ]] && { echo "${match#*:}"; listing="true"; }
		# if a match is found, advance.		[[ YES MATCH ]]
		[[ -n "${match}" && ${listing} == "false" ]] && { ((cp+=1));cv="$(yamlOrder "${path}" ${cp})"; }
		[[ -z "${match}" && ${listing} == "true" ]] && { break; }
		ws=$(( tabL*(${cp}-1) ))
	done < <(echo ${yaml})
	IFS="${_tmp}"
}