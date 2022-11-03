
function editboot() 
{
	# INPUTS : ${x#*=} - dataset
	local VERSION=$1
	local DATASET=$2
	local offset="$(getZFSMountPoint $DATASET)/boot/EFI/boot/refind.conf"
	local POOL="${DATASET%/*}"
	local UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"

	line_number=$(grep -n "${DATASET} " ${offset}  | cut -f1 -d:)
	
	sed -i "/default_selection/c default_selection $DATASET" ${offset}

	# EDIT EXISTING RECORD
	if [[ -n "${line_number}" ]]
	then
		menuL=$((line_number-5))
		loadL=$((line_number-2))
		initrdL=$((line_number-1))
		sed -i "${menuL}s|menuentry.*|menuentry \"Gentoo Linux ${VERSION} ${DATASET}\" |" ${offset}
		sed -i "${loadL}s|loader.*|loader \\/linux\\/${VERSION}\\/vmlinuz|" ${offset}
		sed -i "${initrdL}s|initrd.*|initrd \\/linux\\/${VERSION}\\/initramfs|" ${offset}
	# ADD TO BOOT SPEC
	else
		echo "menuentry \"Gentoo Linux $VERSION $DATASET\"" >> ${offset}
		echo '{' >> ${offset}
		echo '	icon /EFI/boot/icons/os_gentoo.png' >> ${offset}
		echo "	loader /linux/${VERSION#*linux-}/vmlinuz" >> ${offset}
		echo "	initrd /linux/${VERSION#*linux-}/initramfs" >> ${offset}
		echo "	options \"$UUID dozfs root=ZFS=$DATASET default delayacct rw\"" >> ${offset}
		echo '	#disabled' >> ${offset}
		echo '}' >> ${offset}
	fi
}

function clear_mounts()
{
	local offset=$1

	#procs="$(lsof ${mountpoint} | sed '1d' | awk '{print $2}' | uniq)" 
	#echo "killing $(echo $procs | wc -l) process(s)"  2>&1
	#for process in ${procs}; do kill -9 ${process}; done
	#echo "umount $mountpoint"

    dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"

	if [[ -n "$(echo $dir | grep '/dev/')" ]]
	then
		dir="${dir}"
	else
		dir="${dir}\/"
	fi

	output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	echo "$output mounts to be removed" 

	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			umount $mountpoint > /dev/null 2>&1
									# \/ ensures that the root reference is not unmounted
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}

function mounts()
{
    #echo "getting stage 3"
	local offset=$1

	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
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
	ls ${offset}/var/lib/portage/binpkgs
}

function install_kernel()
{
	local offset=$1
	kver="$(getKVER)"
	kver="${kver#*linux-}"
	ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"

	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y binpkg-changed-deps"

	echo "${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz"
	curl -L ${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz

	echo "decompressing modules...  $offset/modules.tar.gz"
	pv $offset/modules.tar.gz | tar xzf - -C ${offset}
	rm ${offset}/modules.tar.gz

}

function mget()
{


	echo "$1 | $2" >&2


	local url="$(echo "$1" | tr -d '*')"			# source_URL
	local destination=$2	# destination_FS

	echo "${url} | ${destination}" >&2

	case ${url%://*} in
		# local rsync only
		rsync)
			rsync -av ${url} ${destination}
		;;
		# local websync only
		http|ftp)
			wget -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination}	--show-progress
			mv ${destination}/${url#*://}* ${destination}/
			url=${url#*://}
			url=${url%%/*}
			echo "${url}" 2>&1
			rm ${destination}/${url} -R
		;;

		# local download only
		ssh)
			host=${url#*://}
			source=${host#*:/}
			host=${host%:/*}
			offset=$(echo "$source" | cut -d "/" -f1)

			# ssh://root@10.1.0.1:/var/lib/portage/patchfiles/

			ssh ${host} "tar cf - /${source}/" | pv --timer --rate | tar xf - -C ${destination}/

			#ssh root@10.1.0.1 "tar cf - /var/lib/portage/patchfiles/" | pv --timer --rate | tar xf - -C /srv/zfs/wSys/systemd/var/lib/portage/patchfiles/

			#destination="/srv/zfs/wSys/systemd"
			#source="/var/lib/portage/patchfiles"
			#offset="/var"

			mv ${destination}/${source} ${destination}/__temp

			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R

			sleep 10
		;;

		# local file move only
		file|*)
			host=${url#*://}
			source=${host#*:/}
			host=${host%:/*}

			#echo "WTF ${url#*://}" 2>&1
			if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
			if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi

			tar cf - /${source} | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${source} ${destination}/__temp
			
			offset=$(echo "$source" | cut -d "/" -f2)

			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;
	esac
	case ${url%://*} in
		http|ftp|ssh|file|'')

		;;
	esac
}

function getKVER() 
{

	# coded for ftp accessable directory listing w/ curl and kernel.mirrors

	url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
	kver="$(curl ${url_kernel} | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep '.tar.gz$')"
	kver=${kver%.tar.gz*}
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
					source="${location#*//}"
					destination="${source%/*}"
					destination="$offset$destination"
					mkdir -p $destination
					if test -f "$source"; then
						#echo "copying $source to $destination"
						cp $source $destination
					#else
						#echo "key not found for $j"
					fi
					#echo "coppied $source to $destination for $j"
				#else
					#echo "nothing to do for $j ..."
				fi
			fi
		done
	done
}