#
#	Eventually mirrors will be invoked through http / passed two args, and yielded a return text / curl
#
#	needs to be slimmed down, patches will become specific to each invokee, but the functionality will be captured
#	in smaller functions : patch_files ; patch_portage ; patch_user ; patch_sys
#

source ./mget.sh


tStamp() {
	echo "obase=16; $(date %s)))" | bc
}

patch_portage() {

    local offset=$1
	local _profile=$2
	local lineNum=0

	common_conf="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/common.conf" | sed 's/ //g' | sed "s/\"/'/g")"
	spec_conf="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${_profile}" | sed 's/ //g' | sed "s/\"/'/g")"

	echo "common_conf = ${common_conf}" 2>&1
	echo "spec_conf = ${spec_conf}" 2>&1

	if [[ -d ${offset}etc/portage/package.license ]];then rm ${offset}etc/portage/package.license -R; fi
	if [[ -d ${offset}etc/portage/package.use ]];then rm ${offset}etc/portage/package.use -R; fi
	if [[ -d ${offset}etc/portage/package.mask ]];then rm  ${offset}etc/portage/package.mask -R;fi
	if [[ -d ${offset}etc/portage/package.accept_keywords ]];then rm ${offset}etc/portage/package.accept_keywords -R;fi

	mget ${spec_conf}.uses ${offset}etc/portage/package.use
	mget ${spec_conf}.keys ${offset}etc/portage/package.accept_keywords
	mget ${spec_conf}.mask ${offset}etc/portage/package.mask
	mget ${spec_conf}.license ${offset}/etc/portage/package.license

	mv ${offset}etc/portage/${spec_conf##*/}.uses ${offset}etc/portage/package.use
	mv ${offset}etc/portage/${spec_conf##*/}.keys ${offset}etc/portage/package.accept_keywords
	mv ${offset}etc/portage/${spec_conf##*/}.mask ${offset}etc/portage/package.mask
	mv ${offset}etc/portage/${spec_conf##*/}.license ${offset}etc/portage/package.license

	sed -i "/MAKEOPTS/c MAKEOPTS=\"-j$(nproc)\"" ${offset}etc/portage/make.conf

	while read line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" ${offset}etc/portage/make.conf
		fi
	done < <(curl ${common_conf} --silent)

	while read line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" ${offset}etc/portage/make.conf	
		fi
	done < <(curl ${spec_conf}.conf --silent)
}

patch_user() {
    local offset=$1
	local _profile=$2
	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/patchfiles.mirrors rsync)"	
	mget ${psrc}/root/ ${offset}/root/ 
	mget ${psrc}/home/ ${offset}/home/ 
}

patch_sys() {
    local offset=$1
	local _profile=$2

	echo "PATCH SYS - ${_profile}"

	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/patchfiles.mirrors rsync)"	
	mget ${psrc}/etc/ ${offset}/etc/ 
	mget ${psrc}/var/ ${offset}/var/ 
	mget ${psrc}/usr/ ${offset}/usr/ 
	# this operation tends to rewrite the root directory w/ portage ownership, not sure how to overwrite rsync behavior in getRSYNC
	mget ${psrc}/ ${offset}/ "--exclude '*'"
	chown root.root /* 
}

#zfs only
function editboot() 
{
	# INPUTS : ${x#*=} - dataset
	local VERSION=$1
	local DATASET=$2
	local offset="$(getZFSMountPoint $DATASET)/boot"
	local POOL="${DATASET%/*}"
	local UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"
	local line_number=$(grep -n "ZFS=${DATASET} " ${offset}/EFI/boot/refind.conf | cut -f1 -d:)
	local menuL
	local loadL
	local initrdL

	echo "line number = ${line_number}" 2>&1

	sed -i "/default_selection/c default_selection $DATASET" ${offset}/EFI/boot/refind.conf

	# EDIT EXISTING RECORD
	if [[ -n "${line_number}" ]]
	then
		menuL=$((line_number-5))
		loadL=$((line_number-2))
		initrdL=$((line_number-1))
		sed -i "${menuL}s|menuentry.*|menuentry \"Gentoo Linux ${VERSION} ${DATASET}\" |" ${offset}/EFI/boot/refind.conf
		sed -i "${loadL}s|loader.*|loader \\/linux\\/${VERSION}\\/vmlinuz|" ${offset}/EFI/boot/refind.conf
		sed -i "${initrdL}s|initrd.*|initrd \\/linux\\/${VERSION}\\/initramfs|" ${offset}/EFI/boot/refind.conf
	# ADD TO BOOT SPEC
	else
		echo "menuentry \"Gentoo Linux $VERSION $DATASET\"" >> ${offset}/EFI/boot/refind.conf
		echo '{' >> ${offset}/EFI/boot/refind.conf
		echo '	icon /EFI/boot/icons/os_gentoo.png' >> ${offset}/EFI/boot/refind.conf
		echo "	loader /linux/${VERSION#*linux-}/vmlinuz" >> ${offset}/EFI/boot/refind.conf
		echo "	initrd /linux/${VERSION#*linux-}/initramfs" >> ${offset}/EFI/boot/refind.conf
		echo "	options \"$UUID dozfs real_root=ZFS=$DATASET default scandelay=3 rw\"" >> ${offset}/EFI/boot/refind.conf
		echo '	#disabled' >> ${offset}/EFI/boot/refind.conf
		echo '}' >> ${offset}/EFI/boot/refind.conf
	fi
}

function clear_mounts()
{
	local offset="$(echo "$1" | sed 's:/*$::')"
	local procs="$(lsof ${offset} 2>/dev/null | sed '1d' | awk '{print $2}' | uniq)" 
    local dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	local output="$(cat /proc/mounts | grep "$dir" | wc -l)"

	if [[ -z ${offset} ]];then exit; fi	# this will break the local machine if it attempts to unmount nothing.

	for process in ${procs}; do kill -9 ${process}; done

	if [[ -n "$(echo $dir | grep '/dev/')" ]]
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
    #echo "getting stage 3"
	local offset=$1
	local mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"

	# MOUNTS
	echo "msize = $mSize"
	mount -t proc proc ${offset}/proc
	mount --rbind /sys ${offset}/sys
	mount --make-rslave ${offset}/sys
	mount --rbind /dev ${offset}/dev
	mount --make-rslave ${offset}/dev
	# because autofs doesn't work right in a chroot ...
	mount -t tmpfs -o size=$mSize tmpfs ${offset}/tmp
	mount -t tmpfs tmpfs ${offset}/var/tmp
	mount -t tmpfs tmpfs ${offset}/run
	echo "attempting to mount binpkgs..."  2>&1
	# this is to build in new packages for future installs, not always present
	mount --bind /var/lib/portage/binpkgs ${offset}/var/lib/portage/binpkgs 
	#ls ${offset}/var/lib/portage/binpkgs
}

function patchProcessor()
{
    local profile=$1
	local offset=$2

	echo $profile 2>&1
	echo $offset 2>&1

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${profile}.patches" | sed 's/ //g')"
	local patch_script="$(curl $url --silent)"

	#
	#
	#	CONVERT THIS TO AN OUTPUT STREAM, DO NOT SAVE TO OFFSET (SHOULD BE INVOKED LOCALLY)
	#
	#
	#

	echo "${patch_script}" > ${offset}patches.sh
}

function install_modules()
{
	local offset=$1
	local kver="$(getKVER)"
	local ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors http)"

	kver="${kver#*linux-}"

	# DEFUNCT ?
	if [[ -d ${offset}/lib/modules/${kver} ]];then exit; fi

	# INSTALL BOOT ENV
	mget ${ksrc}${kver} ${offset}/boot/LINUX/

	# INSTALL KERNEL MODULES
	
	ls ${offset} 2>&1
	mget ${ksrc}${kver}/modules.tar.gz ${offset}/
	echo "mget ${ksrc}${kver}/modules.tar.gz ${offset}/" 2>&1
	ls ${offset} 2>&1

	pv $offset/modules.tar.gz | tar xzf - -C ${offset}
	rm ${offset}/modules.tar.gz	


}

function getKVER() 
{
	# used when kernel source is alongside kernel boot spec folder
	#local kver="$(curl ${url_kernel} | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep '.tar.gz$')"
	#kver=${kver%.tar.gz*}
	# used for kernel boot spec folder
	local url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors ftp)"
	local kver="$(curl "$url_kernel" --silent | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep "\-gentoo")"
	kver="linux-${kver}"
	echo ${kver}
}

function decompress() {
	local src=$1
	local dst=$2
	local compression_type="$(file $src | awk '{print $2}')"
	case $compression_type in
	'XZ')
		pv $src | tar xJf - -C $dst
		;;	
	'gzip')
		pv $src | tar xzf - -C $dst
		;;
	esac
}

#function getG2Version() {
#	local mountpoint=$1
#	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
#	result="${result%/*}"	#peek
#	result="${result%/*}"	#peek
#	result="${result#*/}"	#poke
#	result="${result#*/}"	#poke
#	result="${result#*/}"	#poke
	#echo $result
#	echo "17.1"
#}

function getG2Profile() {
	# assumes that .../amd64/17.X/... ; X will be preceeded by a decimal
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	local _profile=""
	result="${result#*.[0-9]/}"
	result="$(echo ${result} | sed -e 's/^[ \t]*//' | sed -e 's/\ *$//g')"

	case "${result}" in
        'hardened')		    		_profile="17.1/hardened "
        ;;
        'default/linux/amd64/17.1')	_profile="17.1/openrc"
        ;;
        'systemd')					_profile="17.1/systemd "
        ;;
        'desktop/plasma')     		_profile="17.1/desktop/plasma "
        ;;
        'desktop/gnome')			_profile="17.1/desktop/gnome "
        ;;
        'selinux')          		_profile="17.1/selinux "
                        			#echo "${x#*=} is not supported [selinux]"
        ;;
        'plasma/systemd')   		_profile="17.1/desktop/plasma/systemd "
        ;;
        'gnome/systemd')			_profile="17.1/desktop/gnome/systemd "
        ;;
        'hardened/selinux') 		_profile="17.1/hardened/selinux "
                        			#echo "${x#*=} is not supported [selinux]"
        ;;
        esac
		echo "${_profile}" 

}

function getHostZPool () {
	local pool="$(mount | grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo ${pool}
}

function getZFSMountPoint ()
{
	local dataset=$1
	local mountpt="$(zfs get mountpoint ${dataset} 2>/dev/null | sed -n 2p | awk '{print $3}')"
	if [[ -n ${mountpt} ]]; then echo "$(echo ${mountpt} | sed 's:/*$::')/"; fi
}

function compress() {
	local src=$1
	local dst=$2
	local ksize="$(du -sb $src | awk '{print $1}')"
	echo "ksize = $ksize"
	tar cfz - $src | pv -s $ksize  > ${dst}
}

function compress_list() {
	local src=$1
	local dst=$2
	
	#echo "compressing LIST @ $src $dst"
	tar cfz - -T $src | (pv -p --timer --rate --bytes > $dst)
}

function rSync() {
	local src=$1
	local dst=$2
	echo "rsync from $src to $dst"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 $src $dst
}

function zfs_keys() 
{
	# ALL POOLS ON SYSTEM, FOR GENKERNEL
	# pools="$(zpool list | awk '{print $1}') | sed '1 d')"
	# THE POOL BEING DEPLOYED TO ... -- DEPLOYMENT SCRIPT
	#limit pools to just the deployed pool / not valid for genkernel which would attach all pools & datasets
	local dataset=$1
	local offset="$(zfs get mountpoint ${dataset} 2>&1 | sed -n 2p | awk '{print $3}')"
	local dset
	local format
	local location
	local location_type
	local _source

	local pools="$dataset"
	pools="${pools%/*}"
	
	for i in $pools
	do
		# query datasets
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"
		#echo "$listing"

		for j in $listing
		do
			#dSet="$(zpool get bootfs $i | awk '{print $3}' | sed -n '2 p')"
			dSet="$j"
			if [ "$dSet" == '-' ]
			then
				format="N/A"
				location="N/A"
				else
				format="$(zfs get keyformat $dSet | awk '{print $3}' | sed -n '2 p')"
				location="$(zfs get keylocation $dSet | awk '{print $3}' | sed -n '2 p')"
			fi
			# if format == raw or hex & location is a valid file ... if not a valid file , complain
			# ie, not none or passphrase, indicating no key or passphrase, thus implying partition or keyfile type
			if [ $format == 'raw' ] || [ $format == 'hex' ]
			then
				# possible locations are : http/s, file:///, prompt, pkcs11:
				# only concerned with file:///
				location_type="${location%:///*}"
				if [ $location_type == 'file' ]
				then
					# if not, then probably https:/// ....
					# put key file in to initramfs
					_source="${location#*//}"
					destination="${_source%/*}"
					destination="$offset$destination"
					mkdir -p $destination
					if test -f "$_source"; then
						#echo "copying $_source to $destination"
						cp $_source $destination
					#else
						#echo "key not found for $j"
					fi
					#echo "coppied $_source to $destination for $j"
				#else
					#echo "nothing to do for $j ..."
				fi
			fi
		done
	done
}