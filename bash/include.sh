#
#	Eventually mirrors will be invoked through http / passed two args, and yielded a return text / curl
#
#	
#
#

function patches()
{
    local offset=$1
	local _profile=$2
	local lineNum=0

 #   echo "patching system files..." 2>&1

	psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/patchfiles.mirrors rsync)"	
	# the option appended below is contingent on the patchfiles.mirrors type as rsync, wget/http|curl would be -X 

	mget ${psrc}etc/ ${offset}/etc/ "--progress=info2"

	#chown root.root ${offset}

	common_conf="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/common.conf" | sed 's/ //g' | sed "s/\"/'/g")"
	spec_conf="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${_profile}" | sed 's/ //g' | sed "s/\"/'/g")"
	#
	#	machine.conf - chroot in, pull out states/create a dynamic machine configuration. # This justifies running an update on the runtime after a hardware change... 
	#	to include nprocs, kernel module utilization, network adapter configuration, adaptive firewall ???
	#	
	#	

	# PATCHUP *.use ; *.accept_keywords ; *.mask ; *.license 

	# eventually move to directory of, and bulk download instead of individual downloads, and renaming. 
	#	depricated -- mv supercedes the need to delete these files.
	
	if [[ -d ${offset}/etc/portage/package.license ]];then rm ${offset}/etc/portage/package.license -R; fi
	if [[ -d ${offset}/etc/portage/package.use ]];then rm ${offset}/etc/portage/package.use -R; fi
	if [[ -d ${offset}/etc/portage/package.mask ]];then rm  ${offset}/etc/portage/package.mask -R;fi
	if [[ -d ${offset}/etc/portage/package.accept_keywords ]];then rm ${offset}/etc/portage/package.accept_keywords -R;fi

	mget ${spec_conf}.uses ${offset}/etc/portage/package.use
	mget ${spec_conf}.keys ${offset}/etc/portage/package.accept_keywords
	mget ${spec_conf}.mask ${offset}/etc/portage/package.mask
	mget ${spec_conf}.license ${offset}/etc/portage/package.license

	mv ${offset}/etc/portage/${spec_conf##*/}.uses ${offset}/etc/portage/package.use
	mv ${offset}/etc/portage/${spec_conf##*/}.keys ${offset}/etc/portage/package.accept_keywords
	mv ${offset}/etc/portage/${spec_conf##*/}.mask ${offset}/etc/portage/package.mask
	mv ${offset}/etc/portage/${spec_conf##*/}.license ${offset}/etc/portage/package.license

	# THESE CAN BE MODULARIZED ... RAW EDITS FOR NOW
	sed -i "/MAKEOPTS/c MAKEOPTS=\"-j$(nproc)\"" ${offset}/etc/portage/make.conf
	# need a switch-case for kernel modules/pci peeks
	#sed -i "/VIDEO_CARDS/c VIDEO_CARDS=\"${cards}\"" ${offset}/etc/portage/make.conf
	# module for BOOT SYSTEM { EFI/emu/pc}

	while read line; do
		echo "LINE = $line" 2>&1
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX" 2>&1
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf
		fi
	# 																	remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl ${common_conf})

	while read line; do
		echo "LINE = $line" 2>&1
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX" 2>&1
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf	
		fi
	# 																	    remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl ${spec_conf}.conf)
}

function editboot() 
{
	# INPUTS : ${x#*=} - dataset
	local VERSION=$1
	local DATASET=$2
	local offset="$(getZFSMountPoint $DATASET)/boot"
	local POOL="${DATASET%/*}"
	local UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"
	local line_number=$(grep -n "ZFS=${DATASET} " ${offset}  | cut -f1 -d:)
	#local menuL,loadL,initrdL	# predeclarations / local

	# SYNC KERNEL BINARY SOURCES /LINUX/... *SELECT MIRROR SOURCE (KERNELS) TO RSYNC FOR SYNC, NOT D-L
	#local kver=$(getKVER)
	#kver="${kver#*linux-}"
	#local ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors ftp)"	
	
	#echo "kver = ${kver} | $(getKVER)"
	#echo "mget ${ksrc}${kver}/ $offset/LINUX/" 2>&1	
	
	#sleep 30
	#mget ${ksrc}${kver} $offset/LINUX/

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
	local offset=$1
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
	mget ${ksrc}${kver}/modules.tar.gz ${offset}/
	pv $offset/modules.tar.gz | tar xzf - -C ${offset}
	rm ${offset}/modules.tar.gz

}
#
#
# MGET ISSUE, on HTTP MIRRORING PACKAGE.MIRRORS, THE SOURCE FILE CONVERTS TO A FOLDER (desired to be name of destination), THEN SOURCE FILE, OG. Where as I want just desired ... 
#
# ADD SUPPORT FOR STDOUT so as to PIPE to DECOMPRESSION ALGOs, etc...
#
#
#
#
function mget()
{

	local url="$(echo "$1" | tr -d '*')"			# source_URL
	local destination=$2	# destination_FS
	local args=$3
	local offset
	local host
	local _source


	case ${url%://*} in
		# local rsync only
		rsync)
			rsync -av ${args} ${url} ${destination}
		;;
		# local websync only
		#
		#	IF TIME, UNDERSTAND WHY FORMER AND LATER ftp/http mv structures need to be differentiated.
		#
		#
		#
		ftp*)
			wget $args -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination}	--show-progress
			mv ${destination}/${url#*://}XXX ${destination}/
			url=${url#*://}
			url=${url%%/*}
			rm ${destination}/${url} -R
		;;
		http*)
			echo "${destination}" 2>&1
			wget ${args} -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination%/*}	--show-progress
			echo "wget ${args} -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination%/*}	--show-progress" 2>&1
			mv ${destination%/*}/${url#*://} ${destination%/*}
			echo "mv ${destination%/*}/${url#*://} ${destination%/*}" 2>&1
			url=${url#*://}
			echo "url=${url#*://}" 2>&1
			url=${url%%/*}
			echo "url=${url%%/*}" 2>&1
			rm ${destination%/*}/${url} -R 
			echo "rm ${destination%/*}/${url} -R" 2>&1
			#echo "${destination%/*}/|/${url}" 2>&1
			sleep 3

		;;
		# local download only
		ssh)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			offset=$(echo "$_source" | cut -d "/" -f1)
			ssh ${host} "tar cf - /${_source}/" | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${_source} ${destination}/__temp
			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;
		# local file move only
		file|*)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
			if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi
			tar cf - /${_source} | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${_source} ${destination}/__temp
			offset=$(echo "$_source" | cut -d "/" -f2)
			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;
	esac
}

function getKVER() 
{
	local url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors ftp)"
	local kver="$(curl ${url_kernel} | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep '.tar.gz$')"
	kver=${kver%.tar.gz*}
	echo ${kver}
	#sleep 40
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

function getG2Version() {
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result%/*}"	#peek
	result="${result%/*}"	#peek
	result="${result#*/}"	#poke
	result="${result#*/}"	#poke
	result="${result#*/}"	#poke
	echo $result
}

function getG2Profile() {
	# assumes that .../amd64/17.X/... ; X will be preceeded by a decimal
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*.[0-9]/}"
	echo $result
}

function getHostZPool () {
	local pool="$(mount | grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo ${pool}
}

function getZFSMountPoint (){
	local dataset=$1
	echo "$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
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