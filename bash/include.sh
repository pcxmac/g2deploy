#!/bin/bash

#	when refactoring to many types of F/S, remember, disks are configured, before operation, so sense F/S type, and use path
#	to realize important qualifiers, like boot-parts/datasets/subvols,etc....
#
#	ergo, a path is what will be used to determine specs, except in the cases like boot disk partitions where EFI is constant.
#	&&, layered procs/funcs must be used to seamlessly and efficiently apply uniform application across many F/S types. 
#	mounts are assumed prior to spec'ing or operations. It is the responsibility of the 'master' to push mounts before operating on them.

# 	thees functions will eventually be superseded by python  


SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPT_DIR="${SCRIPT_DIR%/*}"

# Normal
colN="\e[1;30m%s\e[m"
# Red
colR="\e[1;31m%s\e[m"
# Green
colG="\e[1;32m%s\e[m"
# Yellow
colY="\e[1;33m%s\e[m"
# Blue
colB="\e[1;34m%s\e[m"
# Pink
colP="\e[1;35m%s\e[m"
# Teal
colT="\e[1;36m%s\e[m"
# White
colW="\e[1;37m%s\e[m"

source ${SCRIPT_DIR}/bash/mget.sh
source ${SCRIPT_DIR}/bash/yaml.sh

#function wg_

# output of 1 = do install, 0 = do nothing, -1 is an error.
function installed_kernel()
{
	_bootdisk=${1:?}
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	pid=$$
	_tmpMount="/boot"

	mkdir -p ${_tmpMount};

	mount ${_bootdisk} ${_tmpMount}

	_latestKernel="$(ls ${_tmpMount}/LINUX/ | sort -r | head -n 1)"
	_latestRef="$(printf '%s\n' ${_latestKernel})"

	_latestKernel=${_latestKernel%-gentoo*}

	_latestBuild="$(ls ${pkgROOT}/source | sort -r | head -n 1)"
	_latestBuild="${_latestBuild%-gentoo*}"
	_latestBuild="${_latestBuild#*linux-}"

	_diffEQ="$(diff ${_tmpMount}/LINUX/${_latestRef}/config* ${pkgROOT}/source/linux/.config | wc -l)"

	# #echo "boot = $_latestKernel ; build = $_latestBuild ; config = $_diffEQ"

	umount ${_tmpMount}
	rmdir ${_tmpMount}

	[[ -z ${_latestKernel} ]] && { printf '1\n'; return; };
	[[ -z ${_latestBuild} ]] && { printf '-1\n'; return; };
	[[ ${_diffEQ} -gt 0 ]] && { printf '1\n'; return; };
	[[ ${_latestKernel} != ${_latestBuild} ]] && { printf '1\n'; return; };
	[[ ${_latestKernel} == ${_latestBuild} ]] && { printf '0\n'; return; };
}


function update_kernel()
{
	local _kver="$(getKVER)"
	pkgHOST="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/host")"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	efi_part="${1:?}"
	# gets rid of trailing slash in order to fit with next sequence.
	_directory="$(printf '%s\n' "${2:?}" | sed 's/\/$//g')"
	type_part="$(blkid "${efi_part}")"

	_installed="$(installed_kernel ${efi_part})"
	[[ ${_installed} == "1" ]] && { printf "kernel up to spec...\n"; return; };

	if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
	then
		# mount boot partition
		echo "update boot ! @ ${efi_part} @ ${dataset} :: ${_directory} >> + $(getKVER)"
		echo "mount ${efi_part} ${_directory}/boot"
		mount "${efi_part}" "${_directory}/boot"
		# edit boot record, refind
		echo "edit boot -- ${kversion}" "${dataset}" "${_directory}"

		_result="$(editboot "${kversion}" "${dataset}" "${_directory}/")"
		echo "install modules -- ${_directory}/"

		# install kernel modules to runtime
		install_modules "${_directory}/"

		# assert new initramfs
		mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/source/ "${_directory}/usr/src/"
		chroot "${_directory}/" /usr/bin/eselect kernel set ${_kver}
		chroot "${_directory}/" /usr/bin/genkernel --install initramfs --compress-initramfs-type=lz4 --zfs
		mv ${_directory}/boot/initramfs-${_kver#*linux-}.img ${_directory}/boot/LINUX/${_kver#*linux-}/initramfs
		# unmount the boot partition
	else
		echo "no mas"
	fi

	umount "${_directory}/boot"

}


function update_runtime()
{
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	echo "UPDATE::RUNTIME_UPDATE !"
	exclude_atoms="-X sys-fs/zfs-kmod -X sys-fs/zfs"
	eselect profile show

	#nmap pkg.hypokrites.me
	#eix dev-haskell/c2hs
	#sleep 10

	PORTAGE_RSYNC_EXTRA_OPTS="--stats" sudo emerge --sync --verbose --backtrack=99 --ask=n;sudo eix-update

	if [[ -f /patches.sh ]]
	then
		echo "PATCHING UPDATES"
		sh < /patches.sh
		rm /patches.sh
	fi

	if [[ -f /package.list && -n "$(cat /package.list | sed '/^#/d' | sed 's/ //g')" ]]
	then
		echo "EMERGE MISSING PACKAGES"
		emerge ${emergeOpts} $(cat /package.list)
		cat /package.list
		rm /package.list
	fi

	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"

	if [[ "${av##*-}" != "${pv##*-}" ]]
	then 
		emerge portage --oneshot --ask=n
	fi

	emerge --info ${emergeOpts} > /update.emerge.info

	sudo emerge ${emergeOpts} -b -uDN --with-bdeps=y @world --ask=n ${exclude_atoms}
	eselect news read new

}


# scope of this function is to build a new kernel, and update portage/kernels
# this function is designed to be used in a 'master' environment, ie a dom0, or root file system.
# it will want to update the 'master' source after building. 
# ASSERTION - repo for kernel source, has to be resident on the local file system.
# update will have to test for this...
function build_kernel()
{

	# need to validate the 'current kernel' to ensure it's config is real. 

	_flag="${2}"
	_bootPart=${1:?}
	_fsType="$(\df -Th ${_bootPart} | awk '{print $2}' | tail -n 1)"
	_rootFS=""
	emergeOpts="--ask=n"

	_kernels_current="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root")"
	_kernel='/usr/src/linux/'

	case ${_fsType} in
		zfs)
			_rootFS="real_root=ZFS=$(getZFSDataSet ${_bootPart})"
		;;
		*)
			printf "unsupported file system type. >[${0}] @ $_fsType for >[${1}]\n"
			return
		;;
	esac

	# current kernel
	cv="$(uname --kernel-release)"
	cv="${cv%-gentoo*}"

	# installed version, latests
	iv="$(qlist -Iv | \grep 'sys-kernel/gentoo-sources' | head -n 1)"
	iv="${iv#*sources-}"

	# current source version (usr/src) >> pkgROOT/source
	#sv="$(eselect kernel list | tail -n $(($(eselect kernel list | wc -l)-1)) | awk '{print $2}' | sort -r | head -n 1)"
	sv="$(readlink ${_kernels_current}/source/linux)"
	sv="${sv%-gentoo*}"
	sv="${sv#*linux-}"


	# master version (pkg.server)
	mv="$(\ls ${_kernels_current}/source/ | \grep -v 'linux$')"
	mv="${mv%-gentoo*}"
	mv="${mv#*linux-}"

	# latest, built version (kernels/current) | 
	lv="$(getKVER)"
	lv="${lv%-gentoo*}"
	lv="${lv#*linux-}"

	# newest version available through portage
	nv="$(equery -CN list -po gentoo-sources | grep -v '\[M' | awk '{print $4}' | tail -n 1)"
	nv="${nv%:*}"
	nv="${nv##*-}"

	#echo "cv = $cv ; lv = $lv ; nv  = $nv"
	_compare="${nv}\n${lv}"

	#echo "lv = $lv ; nv = $nv ; iv = $iv ; cv = $cv ; sv = $sv ; mv = $mv ; compare = $_compare"

	# do nothing case, as it is already installed
	[[ ${lv} == ${nv} ]] && { printf "up to date.\n"; return; };

	# lv, the currently highest installed version, will not be at the bottom if there is a newer unmasked version
	[[ ${lv} != "$(printf $_compare | sort --version-sort | tail -n 1)" ]] && {

	 	[[ ${lv} != ${nv} || ${sv} != ${nv} ]] && { 

			[[ ${_flag} == "-q" ]] && { printf "build new kernel\n"; return; };
			
			echo "installing new version of gentoo-sources.";
			
			emerge $emergeOpts =sys-kernel/gentoo-sources-${nv}; 
		
		} || {	# in the case the current kernel-package is installed, OR, the source version, is the newest package-version and the local version isn't the newest.
			[[ ${_flag} == "-q" ]] && { printf "build old kernel.\n"; return; };
			[[ ! ${_flag} == "-f" ]] && { printf "kernel ${mv} exists.\n"; return; };
		}	

		# suffix might need to be altered to fit possible versioning which meddles with -gentoo
		_suffix="gentoo"
		eselect kernel set linux-${nv}-${_suffix}
		eselect kernel show
		sleep 1

		rm /usr/src/linux/.config
		cat ${_kernels_current}/kernels/current/${lv}-gentoo/config* > /usr/src/linux/.config;
		iv=${nv}
		# if current, even try to check to see if zcat .config is same as repo'd kernel, built to spec (most current)
		(cd ${_kernel}; make clean);
		echo "--- cleaned ---"
		sleep 3
		(cd ${_kernel}; make olddefconfig)
		echo "--- olddefconfig ---"
		sleep 3
		(cd ${_kernel}; make prepare)
		echo "--- prepared ---"
		sleep 3

		(cd ${_kernel}; make -j$(nproc) )
		(cd ${_kernel}; make modules_install)

		_offset=/tmp/$$

		mkdir -p ${_offset}/${nv}-${_suffix}

		(cd ${_kernel}; INSTALL_PATH=/tmp/$$/ make install)
		# requires /etc/portage/bashrc to sign module
		FEATURES="-getbinpkg -buildpkg" \emerge =zfs-kmod-9999
		#genkernel --install initramfs --compress-initramfs-type=lz4 --zfs

		# MOVE KERNELS TO $pkg.root/kernels/current, after depricating older kernel

		(cd ${_offset}/${nv}-${_suffix}/; tar cfvz ./modules.tar.gz /lib/modules/${nv}-${_suffix}; )

		mv ${_offset}/config-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/
		mv ${_offset}/vmlinuz-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/vmlinuz
		mv ${_offset}/System.map-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/

		# initramfs is per install
		#mv ${_offset}/initramfs-${nv}-${_suffix}.img ${_offset}/${nv}-${_suffix}/initramfs

		[[ "$(ls -ail ${_kernels_current}/kernels/current/ | wc -l)" != '2' ]] && {
			[[ -d ${_kernels_current}/kernels/deprecated/$(getKVER) ]] && { rm ${_kernels_current}/kernels/deprecated/$(getKVER) -R; };
			mv ${_kernels_current}/kernels/current/* ${_kernels_current}/kernels/deprecated/
		};
		mv ${_offset}/${nv}-${_suffix}/ ${_kernels_current}/kernels/current/

		# rsync/diff over to new kernel source, change directory to reflect current kernel mget

		sv="$(eselect kernel list | tail -n $(($(eselect kernel list | wc -l)-1)) | awk '{print $2}' | sort -r | head -n 1)"
		[[ -f ${_kernels_current}/source/$(getKVER) ]] && { mv ${_kernels_current}/source/$(getKVER) ${_kernels_current}/source/${sv}; };
		mget ${_kernel} ${_kernels_current}/source/${sv};
		sync
	};
}

function checkHosts()
{
	#local _r=""
	local _s="http ftp rsync ssh"
	local _result
	local _serve
	local _port
	local _config="${SCRIPT_DIR}/config/host.cfg"

	printf "checking hosts: (%s)\n" "${_config}"
	for i in $(printf '%s\n' ${_s})
	do
		_serve="$(findKeyValue ${_config} "server:pkgROOT/repo/${i}")"
		_port="${_serve#*::}"
		_serve="${_serve%::*}"
		_result="$(isHostUp ${_serve} ${_port})"
		_retval="$(printf "${colB} %s ${colB}" '[' "${_result}" ']')"
		printf "\t %-30s : %5s %s \n" "server:pkgROOT/repo/${i}" "${_port}" "$_retval" 
		# 										filter for color
		_result="$(printf '%s\n'\t\t"${_result}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")"

		[[ ${_result} == "INVALID" ]] && { exit; } 
	done
}

function getHostName()
{
	local url=${1:?}
	url=${url#*://}
	url=${url%%/*}
	printf '%s\n' ${url}
}

function isURL()
{
	local _code
	local _URL=${1:?}
	local sType="${_URL%://*}"
	_code="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "$_URL")"
	case $sType in
		ftp)
			case $_code in
				226)		_code='OK'
				;;
				*)			_code='not supported'
				;;
			esac
		;;
		http)
			case $_code in
				200)		_code='OK'
				;;
				*)			_code='not supported'
				;;
			esac
		;;
		rsync)

		 	_host="${_URL#*rsync://}"
		 	_args="${_host#*/}"
		 	_host="${_host%%/*}"
		 	_code="$(rsync $_host::$_args 2>&1)"

		# 	# type cases definitions
		 	[[ -n "$(printf "$_code" | grep 'failed: No such file or directory')" ]] && { _code="none"; }
		 	[[ -n "$(printf "$_code" | grep '@ERROR: Unknown module')" ]] && { _code="no_module"; }

		 	case $_code in
		 		no_module)	_code='no module'
		 		;;
		 		none)		_code='no file/folder'
		 		;;
		 		000)		_code='INVALID'
		 		;;
		 		*)			_code='OK'
		 		;;
		 	esac
		;;
		*)
			_code="unsupported"
		;;
	esac

	[[ ${_code} == "OK" ]] && { printf "${colG}\n" "OK"; } || { printf "${colR}\n" "INVALID"; }

}

function isHostUp()
{
	local host=${1}
	local port=${2}

	# netcat
	local result="$(nc -z -v ${host} ${port} 2>&1 | \grep -E 'open|succeeded')"
	[[ -n ${result} ]] && { printf "${colG}\n" "OK"; } || { printf "${colR}\n" "INVALID"; }
}

function deployUsers()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PXCW0rd | chpasswd' 2>/dev/null
	useradd sysop
	sudo sh -c 'echo sysop:@PXCW0rd | chpasswd' 2>/dev/null
	usermod --home /home/sysop sysop
	usermod -a -G wheel,portage sysop
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop:sysop "${homedir}" -R 2>/dev/null
}

function deployBuildup()
{
	# "${_profile}" 
	local offset="${2:?}"
	# "${dataset}"
	local selection="${4:?}"

	count="$(find "${offset}/" | wc -l)"

	if [[ ${count} -gt 1 ]]
	then
		rm -rv ${offset:?}/* | pv -l -s "${count}" > /dev/null
	else
		echo -e "done "
	fi

	files="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" http "${selection}")"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	case ${serverType%//*} in
		"file:/")
			mget "${filexz#*//}" "${offset}/"
			mget "${fileasc#*//}" "${offset}/"
		;;
		"http:"|"rsync:")
			mget "${filexz}" "${offset}/"
			mget "${fileasc}" "${offset}/"
		;;
	esac

	fileasc="${fileasc##*/}"
	filexz="${filexz##*/}"

	gpg --verify "${offset}/${fileasc}"
	rm ${offset}/${fileasc}

	decompress "${offset}/${filexz}" "${offset}"
	rm ${offset}/${filexz}

	mkdir -p "${offset}/var/lib/portage/binpkgs"
	mkdir -p "${offset}/var/lib/portage/distfiles"
	mkdir -p "${offset}/srv/crypto/"
	mkdir -p "${offset}/var/lib/portage/repos/gentoo"
}

function deploySystem()
{
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"
	echo "DEPLOY::CHECKING PORTAGE ${av##*-}/${pv##*-}"

	if [[ "${av##*-}" != "${pv##*-}" ]]
	then
		emerge --info ${emergeOpts} > /deploy.emerge.info
		emerge ${emergeOpts} portage --oneshot --ask=n
	fi

	echo "DEPLOY::ISSUING UPDATES"
	FEATURES="-collision-detect -protect-owned" emerge ${emergeOpts} -b -uDN --with-bdeps=y @world --ask=n

	echo "APPLYING NECCESSARY PRE-BUILD PATCHES"
	
	sh < /patches.sh

	#rm /patches.sh

	echo "DEPLOY::EMERGE PROFILE PACKAGES"
	FEATURES="-collision-detect -protect-owned" emerge ${emergeOpts} $(cat /package.list)
	#rm /package.list

	echo "DEPLOY::EMERGE ZED FILE SYSTEM"
	emergeOpts="--verbose-conflicts"
	FEATURES="-getbinpkg -buildpkg" emerge ${emergeOpts} =zfs-9999 --nodeps

	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"
	echo "DEPLOY::POST INSTALL UPDATE !!!"
	FEATURES="-collision-detect -protect-owned"emerge -b -uDN --with-bdeps=y @world --ask=n ${emergeOpts}

	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

	eselect news read new

	eix-update
	updatedb
}

function deployServices() 
{
	echo "DEPLOY::EXECUTING SERVICE ROUTINE"
	sh < /services.sh
	rm /services.sh
}

function deployLocales()
{

    local key="${1:?}"
	locale-gen -A
	eselect locale set en_US.utf8

	printf "${colR}\n" "verify /etc/hosts file, which is patched, matches the correct server, otherwise nothing will be found on deployment..."
	emerge-webrsync
	emerge --sync --ask=n

	eselect profile set default/linux/amd64/${key%/openrc}
	eselect profile show

    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
	
}

function tStamp() 
{
	echo "0x$(echo "obase=16; $(date +%s)" | bc)"
}

function patchSystem()	
{
    local profile="${1:?}"
	local type="${2:?}"

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
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common.updates" | sed 's/ //g')" --silent | sed '/^#/d'
			curl "$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${profile}.updates" | sed 's/ //g')" --silent | sed '/^#/d'
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

	psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"	
	common_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common" | sed 's/ //g' | sed "s/\"/'/g")"
	spec_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${_profile}" | sed 's/ //g' | sed "s/\"/'/g")"

	mget "${psrc}/portage" "${offset}/etc/" 

	# if directories exist for new sources, zap them
	if [[ -d ${offset}/etc/portage/package.license ]];then rm "${offset}/etc/portage/package.license" -R; fi
	if [[ -d ${offset}/etc/portage/package.use ]];then rm "${offset}/etc/portage/package.use" -R; fi
	if [[ -d ${offset}/etc/portage/package.mask ]];then rm  "${offset}/etc/portage/package.mask" -R;fi
	if [[ -d ${offset}/etc/portage/package.unmask ]];then rm  "${offset}/etc/portage/package.unmask" -R;fi
	if [[ -d ${offset}/etc/portage/package.accept_keywords ]];then rm "${offset}/etc/portage/package.accept_keywords" -R;fi

	# compile common and spec rules in to /etc/portage/*.use|accept*|(un)mask|license
	echo -e "$(mget ${common_URI}.uses)\n$(mget ${spec_URI}.uses)" | uniq > ${offset}/etc/portage/package.use
	echo -e "$(mget ${common_URI}.keys)\n$(mget ${spec_URI}.keys)" | uniq > ${offset}/etc/portage/package.accept_keywords
	echo -e "$(mget ${common_URI}.mask)\n$(mget ${spec_URI}.mask)" | uniq > ${offset}/etc/portage/package.mask
	echo -e "$(mget ${common_URI}.unmask)\n$(mget ${spec_URI}.unmask)" | uniq > ${offset}/etc/portage/package.unmask
	echo -e "$(mget ${common_URI}.license)\n$(mget ${spec_URI}.license)" | uniq > ${offset}/etc/portage/package.license

	sed -i "/MAKEOPTS/c MAKEOPTS=\"-j$(nproc)\"" ${offset}/etc/portage/make.conf

	while read -r line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" "${offset}/etc/portage/make.conf"
		fi
	# drop empty lines and comments
	done < <(curl "${common_URI}.conf" --silent | sed 's/#.*$//' | sed '/^[[:space:]]*$/d')


	while read -r line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" "${offset}/etc/portage/make.conf"
		fi
	# drop empty lines and comments
	done < <(curl "${spec_URI}.conf" --silent | sed 's/#.*$//' | sed '/^[[:space:]]*$/d' )
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
	# doesn't handle duplicate entries well
	local VERSION="${1:?}"
	local DATASET="${2:?}"
	local offset="${3:?}/boot"
	local POOL="${DATASET%/*}"
	local UUID="$(blkid | \grep "LABEL=\"$POOL\"" | awk '{print $3}' | tr -d '"' | uniq)"
	local lines=$(\grep -n "ZFS=${DATASET} " "${offset}/EFI/boot/refind.conf" | cut -f1 -d:)
	local menuL
	local loadL
	local initrdL
	local line_number

	echo "VERSION = $VERSION" 2>&1
	echo "dataset = $DATASET" 2>&1
	echo "offset $offset" 2>&1
	echo "pool = $POOL" 2>&1
	echo "uuid = $UUID" 2>&1
	echo " line number = $line_number" 2>&1

	sed -i "/default_selection/c default_selection ${DATASET}" "${offset}/EFI/boot/refind.conf"

	if [[ -n "${lines}" ]]
	then
		line_number="$(printf $lines | head -n 1)"
		#for line_number in ${lines}
		#do
			menuL="$((line_number-5))"
			loadL="$((line_number-2))"
			initrdL="$((line_number-1))"
			sed -i "${menuL}s|menuentry.*|menuentry \"Gentoo Linux ${VERSION} ${DATASET}\" |" ${offset}/EFI/boot/refind.conf
			sed -i "${loadL}s|loader.*|loader \\/linux\\/${VERSION}\\/vmlinuz|" ${offset}/EFI/boot/refind.conf
			sed -i "${initrdL}s|initrd.*|initrd \\/linux\\/${VERSION}\\/initramfs|" ${offset}/EFI/boot/refind.conf
		#done
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
	output="$(cat /proc/mounts | \grep "$dir" | wc -l)"

	if [[ -z ${offset} ]];then exit; fi	# this will break the local machine if it attempts to unmount nothing.

	for process in ${procs}; do kill -9 "${process}"; done

	if [[ -n "$(echo "${dir}" | \grep '/dev/')" ]]
	then
		dir="${dir}"
	else
		dir="${dir}/"
	fi

	while [[ "$output" != 0 ]]
	do
		while read -r mountpoint
		do
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | \grep "$dir" | awk '{print $2}')
		output="$(cat /proc/mounts | \grep "$dir" | wc -l)"
	done

}

function mounts()
{
	local offset="${1:?}"
	local mSize="$(cat /proc/meminfo | column -t | \grep 'MemFree' | awk '{print $2}')"
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

	pkgHOST="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/host")"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	# need a fusable link mechanism, not fuse, rather a modular/extenisble system of interlinking assets.

	mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/binpkgs "${offset}/var/lib/portage/binpkgs"
	mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/distfiles "${offset}/var/lib/portage/distfiles"

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

	#	sleep 20
}

function install_modules()
{
	local offset="$(printf '%s\n' "${1:?}" | sed 's/\/$//g')"
	local kver="$(getKVER)"
	local ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/kernel ftp)"

	kver="${kver#*linux-}"

	mget "${ksrc}${kver}/" "${offset}/boot/LINUX/"
	mget "${ksrc}${kver}/modules.tar.gz" "${offset}/modules.tar.gz"
	echo "decompressing ${ksrc}${kver}/modules.tar.gz" 2>&1
	pv "${offset}/modules.tar.gz" | tar xzf - -C "${offset}/"
	rm "${offset}/modules.tar.gz"	
}

function getKVER() 
{
	local url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/kernel" ftp)"
	local kver="$(curl "$url_kernel" --silent | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep "\-gentoo" | sort -r | head -n 1 )" 
	# default to uname, if no source repo detected.
	[[ -z "${kver}" ]] && { kver="$(uname --kernel-release)"; };
	kver="linux-${kver}"
	printf '%s\n' "${kver}"
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
	local pool="$(mount | \grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo "${pool}"
}

function getZFSDataSet ()
{
	local mountpt="${1:?}"
	local dataset="$(zfs get mountpoint "${mountpt}" 2>/dev/null | sed -n 2p | awk '{print $1}')"
	if [[ -n ${dataset} ]]; then echo "$(echo ${dataset} | sed 's:/*$::')"; fi
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
		listing="$(zfs list | \grep "${i}/" | awk '{print $1}')"

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
