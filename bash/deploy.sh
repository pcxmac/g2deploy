!/bin/bash

    # INPUTS    BUILD=(ex.)'hardened'  	- build profile
    #           WORK=chroot offset		- working directory for install, skip if exists (DEPLOY).
	#			BOOT=/dev/sdX			- install to boot device, after generating image
	#			RECV=XXX				- RECV from server remotely, requires the host to be booted through medium, and mounted (ALL F/S) BTRFS+ZFS are block sends
	#			

	#	future features : 	
	#		test to see if pool exists, add new zfs datasets if no dataset, other partition types.
	#		boot medium, 
	#		

	SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
	SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

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

### NEED A UNIVERSAL TRANSPORT MECHANISM FOR SYNCING ALL FILES. SCP, RSYNC ?
#
#		SYNC() HOST w/ SOURCE
#		SEND TO SOURCE DESTINATION
#		RECV FROM SOURCE DESTINATION
#		COMPRESSION AND ENCRYPTION ARE TRANSPARENT
#		
#
#############################################################################

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

function users()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd' 2>/dev/null
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd' 2>/dev/null
	echo "home : sysop"
	usermod --home /home/sysop sysop
	echo "wheel : sysop"
	usermod -a -G wheel sysop
	echo "shell : sysop"
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop.sysop ${homedir} -R 2>/dev/null
	echo "homedir"
}

function clear_mounts()
{
	local offset=$1

    dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	if [[ -n "$(echo $dir | grep '/dev/')" ]]
	then
		dir="${dir}"
	else
		dir="${dir}\/"
	fi

	output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	echo "$output mounts to be removed" 2>&1
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}

function buildup()
{
    #echo "getting stage 3"
	local profile=$1
	local offset=$2
	local dSet=$3

	setExists=
	snapshot="$(zfs list -o name -t snapshot | sed '1d' | grep '${dset}')"

	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ $offset"
	echo "deleting old files (calculating...)"
	count="$(find $offset/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $offset/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... $offset"

	files="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/release.mirrors ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	echo "X = ${serverType%//*} :: $files @ $profile"

	case ${serverType%//*} in
		"file:/")
			echo "RSYNCING" 2>&1
			rsync -avP ${filexz#*//} ${offset}
			rsync -avP ${fileasc#*//} ${offset}
		;;
		"http:")
			echo "WGETTING" 2>&1
			wget $filexz	--directory-prefix=${offset}
			wget $fileasc	--directory-prefix=${offset}
		;;
	esac

	fileasc=${fileasc##*/}
	filexz=${filexz##*/}

	gpg --verify $offset/$fileasc
	rm $offset/$fileasc

	echo "decompressing $filexz...@ $offset" 2>&1
	decompress $offset/$filexz $offset
	rm $offset/$filexz
	#sleep 30

    echo "setting up mounts"
	mkdir -p ${offset}/var/lib/portage/binpkgs
	mkdir -p ${offset}/var/lib/portage/distfiles
	mkdir -p ${offset}/srv/crypto/
	mkdir -p ${offset}/var/lib/portage/repos/gentoo

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

function system()
{
	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y"
	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	echo "EMERGE PROFILE PACKAGES !!!!"
	pkgs="/package.list"
	emerge $emergeOpts $(cat "$pkgs")

	emergeOpts=""
	FEATURES="-getbinpkg -buildpkg" emerge $emergeOpts =zfs-9999 --nodeps
	
	#echo "SETTING SERVICES"
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import
	eix-update
	updatedb
}

function services()
{
	local lineNum=0
	local service_list=$1

	bash <(curl "${service_list}")
}

function install_kernel()
{
	local offset=$1
	kver="$(getKVER)"
	kver="${kver#*linux-}"
	ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"

	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y "

	echo "${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz"
	curl -L ${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz

	echo "decompressing modules...  $offset/modules.tar.gz"
	pv $offset/modules.tar.gz | tar xzf - -C ${offset}
	rm ${offset}/modules.tar.gz

}

function install_modules()
{
	echo "empty"
}


function patches()
{
    local offset=$1
	local profile=$2
	local lineNum=0

    echo "patching system files..." 2>&1
    rsync -a --info=progress2 /var/lib/portage/patchfiles/ ${offset}

	#
	#	build profile musl throws this in to the trash, lots of HTML/XML are injected
	#

	echo "patching make.conf..." 2>&1
	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf
		fi
	# 																	remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/common.conf" | sed 's/ //g' | sed "s/\"/'/g"))

	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf	
		fi
	# 																	    remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/${_profile}.conf" | sed 's/ //g' | sed "s/\"/'/g"))
}

function locales()
{

    local key=$1
	locale-gen -A
	eselect locale set en_US.utf8
	emerge-webrsync

	#MOUNT --BIND RESOLVES NEED TO CONTINUALLY SYNC, IN FUTURE USE LOCAL MIRROR
	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
		
	#	{key%/openrc} :: is a for the edgecase 'openrc' where only that string is non existent with in eselect-profile
	eselect profile set default/linux/amd64/${key%/openrc}
}

function pkgProcessor()
{
    local profile=$1
	local offset=$2

	echo $profile 2>&1
	echo $offset 2>&1

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url)"
	echo ":::: $url"
	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url)"
	echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	echo "${diffPkgs}" > ${offset}/package.list
}

###################################################################################################################################

	# check mount, create new mount ?
	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f system
	export -f services
	export -f install_modules

	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	profile=""				#	the build profile of the install
	selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }

    for x in $@
    do
        case "${x}" in
            work=*)
                #? zfs= btrfs= generic= tmpfs=
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"
            ;;
        esac
    done

    for x in $@
    do
        #echo "before cases $x"
        case "${x}" in
            build=*)
                echo "build..."
                # DESIGNATE BUILD PROFILE
                _profile="invalid profile"

                selection="${x#*=}"

                case "${x#*=}" in
                    # special cases for strings ending in selinux, and systemd as they can be part of a combination
                    #'musl')
                        # space at end limits selinux	...		NOT SUPPORTED
                    #    _profile="17.0/musl/hardened "
                    #;;
                    'hardened')		    _profile="17.1/hardened "
                    ;;
                    'openrc')			_profile="17.1/openrc"
                    ;;
                    'systemd')			_profile="17.1/systemd "
                    ;;
                    'plasma')           _profile="17.1/desktop/plasma "
                    ;;
                    'gnome')			_profile="17.1/desktop/gnome "
                    ;;
                    'selinux')          _profile="17.1/selinux "
                        				echo "${x#*=} is not supported [selinux]"
                    ;;
                    'plasma/systemd')   _profile="17.1/desktop/plasma/systemd "
                    ;;
                    'gnome/systemd')	_profile="17.1/desktop/gnome/systemd "
                    ;;
                    'hardened/selinux') _profile="17.1/hardened/selinux "
                        				echo "${x#*=} is not supported [selinux]"
                    ;;
                    *)					_profile="invalid profile"
                    ;;
                esac
            ;;
        esac
    done

	echo $(getKVER)

	clear_mounts ${directory}

	buildup ${_profile} ${directory} ${dataset}
	zfs_keys ${dataset}
	echo "certificates ?"

	echo "pkgprocessor :"
	pkgProcessor ${_profile} ${directory}
	echo "patches:"

	patches ${directory} ${_profile}
	chroot ${directory} /bin/bash -c "locales ${_profile}"

	install_kernel ${directory}

	chroot ${directory} /bin/bash -c "system"

	chroot ${directory} /bin/bash -c "install_modules"

	chroot ${directory} /bin/bash -c "users ${_profile}"

	services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors * )/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"

	chroot ${directory} /bin/bash -c "services ${services_URL}"
	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key ${dataset}

	clear_mounts ${directory}
	ls ${offset}
	zfs snapshot ${dataset}@safe

	# potential cleanup items
	#
	#	move binpkgs for client to /tmp as well, disable binpkg building
	#	reflash modules, or separate modules and kernel out...
	#	autofs integration w/ boot drive
	#	clear mounts 
	#
