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

#
#	X	boot updates ... ./update.sh work=pool/dataset update { boot | boot=XXXX }
#	X	XXXX = UUID 		>> echo "/dev/${$(readlink /dev/disk/by-uuid/4D8D-8985)##*/}" ... then by /dev/...
#	X	XXXX = /dev/xxx#	>> file -s XXXX | grep 'FAT (32-bit)' | grep 'XXXX: DOS/MBR boot sector'
#	X	XXXX = ./boot.cfg
#	X	boot, by itself will :
#	X	look at the kernel command line : XXXX
#	X	look at a partition mounted on /boot
#		
#	for boot.cfg, a uniform boot entry must be made in a systemwide configuration file (~yml)
#
#	X use findboot, to assign to autofs, @ bastion
#	use findboot, to update bootrecords, via : find_bootType

#
#	find_bootType = mbr/efi ... mbr = { grub, ... } | efi = { grub, refind } << SUPPORTED
#	returns X,Y ex "MBR,GRUB" || "EFI,REFIND"
#	ONLY REFIND SUPPORTED FOR NOW !!!	
#
#	function get_bootYAML
#	returns yaml block from boot record, based on $(find_bootType) return message
#
#	function update_bootYAML
#	updates yaml block, based on standard yaml type, which has it's configuration standardized
#
#	function put_bootYAML
#	rewrites boot record (grub or refind)
#	saves old version *.save$(DATE)

function logTicket(){

	local _file=${1:?}
	local _yaml=${2:?}	# yaml coded string for trouble ticket, to be logged.
	# ticket - yaml format
	#
	#	application
	#	date/time
	#	description ( app specific error code | error title )
	#	notes (long string)
	#
	#	
	#	

}

# gitMaintain ./clone-As ${repo}	... ${repo} can be a URL to more ... if no ${repo} then look for
function gitMaintain() {

	_location=""
	_repo=""

	# pkgREPO="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository")"
    # _repository="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository")"
    # _repositories="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository/-")"

	# # 
	# # if location isn't valid, delete, and ...

    # [[ ! -d ${pkgREPO} ]] && { mkdir -p ${pkgREPO}; };

	# HOST SPECIFIC REPOS
    # for x in $(echo "${_repositories}")
    # do
    #     _repo="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository/${x}")"
    #     printf "%s\n" "${_repository}${x} @ ${_repo}"
    #     [[ ! "$(cd ${_repository}${x} 2>/dev/null;git remote get-url origin)" == ${_repo} ]] && {
    #         [[ -d ${_repository}${x} ]] && { rm ${_repository}${x} -R; };
    #         git -C "${_repository}" clone ${_repo} ${x};
    #     } || {
    #         git -C "${_repository}${x}" fetch --all;
    #         git -C "${_repository}${x}" pull;
    #     };
    # done

	# BUILD SERVER REPOS
    # for x in $(echo "${_repositories}")
    # do
    #     _repo="$(findKeyValue "${SCRIPT_DIR}/config/repos.eselect" "repositories/${x}")"
    #     bad_repo="$(git ls-remote ${_repository}${x} 2>&1 | \grep 'fatal')";
    #     #echo ":: ${_repository}${x} @ ${_repo}"

    #     [[ -z ${bad_repo} ]] && {
    #         git -C "${_repository}${x}" fetch --all;
    #         git -C "${_repository}${x}" pull;
    #     } || {
    #         #echo "bad repo @ ${x} | ${bad_repo}";
    #         [[ -d ${_repository}${x} ]] && { rm ${_repository}${x} -R; };
    #         git -C "${_repository}" clone ${_repo} ${x};
    #     };

    # done


	# if location doesn't exist, insantiate new repo
	# 
	# if location is valid : 
	# 	reset head to master (get )
	#		git rev-parse --verify master == ... --verify HEAD
	# 	

	# error conditions : 
	#	bad repo url ... w/. filters for cgit, ...
	#	requires login/password
	#	bad arg conditions, one of the strings is invalid

}

function zfsMaxSupport() { 

	version="$(mget https://raw.githubusercontent.com/openzfs/zfs/master/META | \grep 'Linux-Maximum' | sed 's/ //g' )";
	version="${version#*:}";
	version="$(equery -CN list -po gentoo-sources 2>/dev/null | \grep "${version}" | tail -1 | sed $'s/ /\\n/g' | \grep '^sys-kernel')";
	echo "linux-${version#*:}-gentoo";
}

function find_UUID() {

	# /dev/address of disk
	local rType="${1}"
	local lType=''

	[[ -n ${rType} ]] && {
		lType="$(ls /dev/disk/by-uuid/ -ail | grep "${rType##*/}"  | awk '{print $10}')";
	} || {
		lType="";
	};

	echo $lType
}


function find_boot() {

	# UUID or block device
	local param=$1
	local rType='';
	local lType='';

	[[ -n ${param} ]] && {
		
		#echo "a"
		
		[[ "$(echo "/dev/${$(readlink /dev/disk/by-uuid/${param})##*/}")" != "/dev/" ]] && { 
			rType=${param}; 
			#echo "value passed - uuid";
		};
		[[ -n "$(file -s ${param} | \grep 'FAT (32 bit)' | grep "${param}: DOS/MBR boot sector")" ]] && { 
			param="$(ls -ail /dev/disk/by-uuid/ | \grep ${param##*/} | awk '{print $10}')";
			rType="${param##*/}";
			#echo "value passed - disk"
		};
	} || {

		#echo "b"

		# if no valid uuid or device passed
		# check /boot in /proc/mounts
		[[ -z ${rType} ]] && {

			#echo "1"

			rType="$(cat /proc/mounts | \grep ' /boot ' | sed $'s/ /\\n/g')"; 
			rType="$(echo "${rType}" | \grep '^/dev/')"; 
			[[ -n ${rType} ]] && {
				rType="$(ls -ail /dev/disk/by-uuid/ | \grep ${rType##*/} | awk '{print $10}')";
				rType="${rType##*/}";
			};
		};
		# check kernel /proc/cmdline
		[[ -z ${rType} ]] && { 

			#echo "2"

			rType="$(cat /proc/cmdline | \grep 'boot=' | sed $'s/ /\\n/g')"; 
			[[ -n ${rType} ]] && {
				rType="$(echo "${rType}" | \grep '^boot=')";
				rType="${rType#*=}";
			};
		};
	};
	#echo $rType
	#ls -ail /dev/disk/by-uuid/${rType}

	[[ -L /dev/disk/by-uuid/${rType} ]] && {
		lType="$(ls /dev/disk/by-uuid/${rType} -ail | awk '{print $12}')";
		lType="/dev/${lType##*/}";
	}
	echo $lType
}

function find_bootType {

	# multiple boot specs are only supported through yaml configs, at higher order functions, this gives the best priority response
	#
	#	priority = 	MBR, then EFI
	#				REFIND, then GRUB :: EFI,GRUB => EFI,REFIND => MBR,GRUB
	#	supported permutations = { MBR,GRUB ; EFI,GRUB ; EFI, REFIND ; '' } = LTYPE

	# dev reference only [mbr]
	local param=$1 
	local rType='';

	# if not valid block device
	[[ -e ${param} ]] && { exit; };

	# priority >checklist<


	# check for EFI + GRUB
	# /boot/grub/grub/grub.cfg + /boot/EFI/bootx64.efi - /boot/EFI/refind* { signature }


	# check for EFI + REFIND
	#/boot/EFI/boot/refind_x64.efi + /boot/EFI/boot/refind.conf + /boot/EFI/bootx64.efi	{ signature }

	# check for MBR + GRUB
	# scan mbr w/ file executable...
	[[ -n $(file -s ${param} | grep 'GRand Unified Bootloader') ]] && { 
	
		rType='MBR,GRUB'; 
	};



	# efi partitions exist on separate DOS/EFI partitions (32 bit)
	# REFIND : 	/boot/EFI/boot/refind.conf
	#			/boot/EFI/bootx64.efi
	#			
	# GRUB : 	/




}

# output of 1 = do install, 0 = do nothing, -1 is an error.
function installed_kernel()
{
	_bootdisk="${1}"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	pid=$$
	_tmpMount="/tmp/boot_${pid}"

	mkdir -p ${_tmpMount}
	mount -t vfat ${_bootdisk} ${_tmpMount} 

	_latestKernel="$(ls ${_tmpMount}/LINUX/ | sort -r | head -n 1)"
	_latestRef="$(printf '%s\n' ${_latestKernel})"

	_latestKernel=${_latestKernel%-gentoo*}

	_latestBuild="$(ls ${pkgROOT}/source | sort -r | head -n 1)"
	_latestBuild="${_latestBuild%-gentoo*}"
	_latestBuild="${_latestBuild#*linux-}"

	_diffEQ="$(diff ${_tmpMount}/LINUX/${_latestRef}/config* ${pkgROOT}/source/linux/.config | wc -l)"

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
	# scope of this function : used to update the kernel, kernel modules on an existing runtime/installation. Requires an EFI partition.

	_target=$1
	_efiPart=$2

	# this function binds to the mount point, 
	# decides if current kernel is newest (if so, do not execute...)
	# old kernels ...
	# 
	# mounts the efi partition, after mounting system mounts

	# go in to boot
	# generate initramfs
	# edit boot record
	# update modules

	local _kver="$(getKVER)"
	pkgHOST="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/host")"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	efi_part="${1:?}"
	# gets rid of trailing slash in order to fit with next sequence.
	_directory="$(printf '%s\n' "${2:?}" | sed 's/\/$//g')"
	type_part="$(blkid "${efi_part}")"

	# mount boot partition
	#echo "update boot ! @ ${efi_part} @ ${dataset} :: ${_directory} >> + $(getKVER)"
	#echo "mount ${efi_part} ${_directory}/boot"

	mount "${efi_part}" "${_directory}/boot"
	# edit boot record, refind
	#echo "edit boot -- ${kversion}" "${dataset}" "${_directory}"
	editboot "${kversion}" "${dataset}" "${_directory}/"
	#echo "install modules -- ${_directory}/ @ $_result"
	umount "${_directory}/boot"

	# will use rsync to overwrite different/new files.
	mget ${pkgROOT}/kernels/current/${_kver}-gentoo/modules.tar.gz /tmp/modules_${_kver}/
	tar xfvz /tmp/modules_${_kver}/modules.tar.gz
	mget /tmp/modules_${_kver}/lib/ ${_directory}/lib/
	rm /tmp/modules_${_kver} -R

	_installed="$(installed_kernel ${efi_part})"
	[[ ${_installed} == "1" ]] && { printf "kernel up to spec...\n"; return; };

	if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
	then
		# assert new initramfs
		#mount --bind ${pkgROOT}/source/ ${_directory}/usr/src/
		#mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/source/ "${_directory}/usr/src/"
		chroot "${_directory}/" /usr/bin/eselect kernel set ${_kver}
		chroot "${_directory}/" /usr/bin/genkernel --install initramfs --compress-initramfs-type=lz4 --zfs
		mv ${_directory}/boot/initramfs-${_kver#*linux-}.img ${_directory}/boot/LINUX/${_kver#*linux-}/initramfs
		# unmount the boot partition

		umount "${_directory}/boot"

	else
		echo "no mas"
	fi
}

function sync_type()
{
	syncURI=${1:?}
	
	#	git  = *.git$
	#	rsync= ^rsync:

	case ${syncURI} in
		*.git)
			echo "git"
		;;
		rsync:*)
			echo "rsync"

		;;
	esac
}

function update_runtime()
{
#	local emergeOpts="--backtrack=99 --verbose --tree --verbose-conflicts"
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	echo "UPDATE::RUNTIME_UPDATE !"

	# do not include kernel or kernel modules...
	exclude_atoms=" -X sys-kernel/vanilla-sources"
	exclude_atoms+=" -X sys-kernel/rt-sources"
	exclude_atoms+=" -X sys-kernel/git-sources"
	exclude_atoms+=" -X sys-kernel/gentoo-sources"
	exclude_atoms+=" -X sys-fs/zfs"
	exclude_atoms+=" -X sys-fs/zfs-kmod"

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
	eselect news read new 1>/dev/null  2>>/emerge.errors
	#eclean distfiles

}

# scope of this function is to build a new kernel, and update portage/kernels
# this function is designed to be used in a 'master' environment, ie a dom0, or root file system.
# it will want to update the 'master' source after building. 
# ASSERTION - repo for kernel source, has to be resident on the local file system.
# update will have to test for this...
function build_kernel()
{

	# need to validate the 'current kernel' to ensure it's config is real.  ???

	_rebuild=true

	_flag="${2}"
	_bootPart=${1:?}
	_fsType="$(\df -Th ${_bootPart} | awk '{print $2}' | tail -n 1)"
	_rootFS=""
#	local emergeOpts="--ask=n --backtrack=99 --verbose --tree --verbose-conflicts"
	local emergeOpts="--ask=n --buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

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

	# installed version, latest
	iv="$(qlist -Iv | \grep 'sys-kernel/gentoo-sources' | head -n 1)"
	iv="${iv#*sources-}"

	# current source version (usr/src) >> pkgROOT/source
	#sv="$(eselect kernel list | tail -n $(($(eselect kernel list | wc -l)-1)) | awk '{print $2}' | sort -r | head -n 1)"
	sv="$(readlink /usr/src/linux)"
	_sv="${sv#*linux-}"
	_sv="${_sv%-gentoo*}"
	sv="${_sv}${sv#*-gentoo}"

	# master version (pkg.server) ..... IF SOURCE EXISTS ????
	mv="$(cd ${_kernels_current}/source/; make kernelversion)"
	_mv="${mv#*linux-}"
	_mv="${_mv%-gentoo*}"
	mv="${_mv}${mv#*-gentoo}"


	# latest, built version (kernels/current) | 
	lv="$(getKVER)"
	_lv="${lv#*linux-}"
	_lv="${_lv%-gentoo*}"
	lv="${_lv}${lv#*-gentoo}"

	# newest version available through portage
	nv="$(equery -CN list -po gentoo-sources | \grep -v '\[M' | \grep -v '\[?' | awk '{print $4}' | tail -n 1)"
	nv="${nv%:*}"
	nv="${nv##*gentoo-sources-}"
	nv="${nv%:*}"

	#echo "cv = $cv ; lv = $lv ; nv  = $nv"
	_compare="${nv}\n${lv}"
	_compare="$(printf $_compare | sort --version-sort | tail -n 1)"

	#echo "lv = *$lv* ; nv = *$nv* ; iv = *$iv* ; cv = *$cv* ; sv = *$sv* ; mv = *$mv* ; compare = *$_compare* ; flag = *$_flag*" 2>&1
	
	# do nothing case, as it is already installed
	[[ ${lv} == ${nv} ]] && { printf "up to date.\n"; return; };

	#echo "$_compare :: $_flag "

	[[ ${lv} != "$_compare" || $_flag == '-f' ]] && {


		# if current installed source version does not equal latest build
		[[ ${sv} != ${nv} ]] && { 
		 		emerge =sys-kernel/gentoo-sources-${nv} --ask=n --buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts;
		};

		_suffix="gentoo"
		# for -r shred
		[[ -n "$(printf '%s' ${nv} | \grep '\-r' )" ]] && { _suffix="${_suffix}-r${nv#*-r}"; nv=${nv%%-r*}; };
		_offset=/tmp/$$
		mkdir -p ${_offset}/${nv}-${_suffix}

		eselect kernel set linux-${nv}-${_suffix}
		eselect kernel show
		sleep 3

		[[ -f /usr/src/linux/.config ]] && { rm /usr/src/linux/.config; }; 
		#[[ -f /usr/src/linux/.config ]] && { zcat /proc/config.gz > /usr/src/linux/.config; };
		[[ -d ${_kernels_current}/kernels/current/${lv}-gentoo/ ]] && {
		 	cat ${_kernels_current}/kernels/current/${lv}-gentoo/config* > /usr/src/linux/.config;
		} || {
		 	zcat /proc/config.gz > /usr/src/linux/.config;
		};

		iv=${nv}
		# if current, even try to check to see if zcat .config is same as repo'd kernel, built to spec (most current)
		(cd ${_kernel}; make clean);
		printf ">>> cleaned\n"
		sleep 3
		(cd ${_kernel}; make olddefconfig);
		printf ">>> olddefconfig\n"
		sleep 3
		(cd ${_kernel}; make prepare);
		printf ">>> prepared\n"
		sleep 3
		(cd ${_kernel}; make -j$(nproc));
		printf ">>> kernel built\n"
		sleep 3
		(cd ${_kernel}; INSTALL_PATH=${_offset}/${nv}-${_suffix} make install);
		printf ">>> kernel installed\n"
		sleep 3
		(cd ${_kernel}; make modules_install);
		# requires /etc/portage/bashrc to sign module
		FEATURES="-getbinpkg -buildpkg" \emerge =zfs-kmod-9999 --oneshot

		# sign 'extra' modules
		_hashAlgo="$(cat ${_kernel}/.config | grep 'CONFIG_MODULE_SIG_HASH' | sed -e 's/\"//g' )"
		_hashAlgo="${_hashAlgo#*=}"
		_modules="$(ls -d /lib/modules/${nv}-${_suffix}/extra/*)"
		for _module in ${_modules}
		do
			printf 'SIGN\t%s\n' "${_module}"
			(cd ${_kernel}; ./scripts/sign-file ${_hashAlgo} ./certs/signing_key.pem ./certs/signing_key.x509 $_module);
		done
		sleep 3

		# compress and store modules in a portable format
		(cd ${_offset}/${nv}-${_suffix}/; tar cfvz ./modules.tar.gz /lib/modules/${nv}-${_suffix};);
		printf ">>> modules installed\n"
		sleep 3

		# save kernel package to kernels/current
		#mv ${_offset}/config-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/
		#mv ${_offset}/vmlinuz-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/vmlinuz
		#mv ${_offset}/System.map-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/
		[[ "$(\ls ${_kernels_current}/kernels/current/ | wc -l)" > 0 ]] && { mv ${_kernels_current}/kernels/current/* ${_kernels_current}/kernels/deprecated/; };
		# current kernel
		printf "saving current kernel...\n"
		# relabel kernel to 'vmlinuz'
		mv ${_offset}/${nv}-${_suffix}/vmlinuz-${nv}-${_suffix} ${_offset}/${nv}-${_suffix}/vmlinuz
		mget ${_offset}/ ${_kernels_current}/kernels/current/ --delete -Dogtplr
		# current source for kernel ... this directory can be linked to, as the source for getKVER
		printf "saving current kernel source ...\n"
		mget /usr/src/linux-${nv}-${_suffix}/ ${_kernels_current}/source/ --checksum --delete -Dogtplr
		#echo "lv = *$lv* ; nv = *$nv* ; iv = *$iv* ; cv = *$cv* ; sv = *$sv* ; mv = *$mv* ; compare = *$_compare* ; flag = *$_flag*" 2>&1
		#rm ${_offset} -R
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
		printf "$_serve"
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
	local _codeq
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
	local result="$(nc -w 3 -z -v ${host} ${port} 2>&1 | \grep -E 'open|succeeded')"
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

	echo "---error log---" > ${offset}/emerge.errors

	#echo "count = $count"

	if [[ ${count} -gt 1 ]]
	then
		rm -rv ${offset:?}/* | pv -l -s "${count}" > /dev/null
	else
		echo -e "done "
	fi

	#echo "test"

	files="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" http "${selection}")"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	#echo "$files"
	#echo "$serverType"

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

	# PARENT INSTALLER NEEDS TO HAVE 'app-portage/getuto' INSTALLED FOR THE SIG TO PICK UP CORRECTLY

	gpg --verify "${offset}/${fileasc}"  
	rm ${offset}/${fileasc}

	decompress "${offset}/${filexz}" "${offset}"  
	rm ${offset}/${filexz}

	# just use patchfiles ...

	#mkdir -p "${offset}/var/lib/portage/binpkgs"
	#chown portage:portage "${offset}/var/lib/portage/binpkgs"
	#chmod 755 "${offset}/var/lib/portage/binpkgs"
	#mkdir -p "${offset}/var/lib/portage/distfiles"
	#chown portage:portage "${offset}/var/lib/portage/distfiles"
	#chmod 755 "${offset}/var/lib/portage/distfiles"
	#mkdir -p "${offset}/var/lib/portage/repos/gentoo"
	#chown portage:portage "${offset}/var/lib/portage/repos/gentoo"
	#chmod 755 "${offset}/var/lib/portage/repos/gentoo"

	#mkdir -p "${offset}/srv/crypto/"
}

function deploySystem()
{


	gpg --list-secret-keys --keyid-format=long
	#sleep 3

	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

#	local emergeOpts="--backtrack=99 --verbose --tree --verbose-conflicts"

	echo "installing gpg keys"  >>/emerge.errors
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

	emerge ${emergeOpts} sec-keys/openpgp-keys-gentoo-auth sec-keys/openpgp-keys-gentoo-developers sec-keys/openpgp-keys-gentoo-release  2>>/emerge.errors
	gpg --import /usr/share/openpgp-keys/gentoo-auth.asc 2>>/emerge.errors
	gpg --import /usr/share/openpgp-keys/gentoo-developers.asc 2>>/emerge.errors
	gpg --import /usr/share/openpgp-keys/gentoo-release.asc 2>>/emerge.errors
	# end of gpg 

	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"
	echo "DEPLOY::CHECKING PORTAGE ${av##*-}/${pv##*-}" >> /emerge.errors

	_DISTDIR="$(emerge --info | \grep "^DISTDIR" | sed -e 's/\"//g')"
	_DISTDIR="${_DISTDIR#*=}";

	chown portage:portage $_DISTDIR -R

	# portage
	if [[ "${av##*-}" != "${pv##*-}" ]]
	then
		emerge --info ${emergeOpts} > /deploy.emerge.info  2>>/emerge.errors
		emerge ${emergeOpts} portage --oneshot --ask=n  2>>/emerge.errors
	fi

	# SYNC
	emerge --sync --ask=n  --quiet 2>>/emerge.errors

	echo "DEPLOY::ISSUING UPDATES"  >> /emerge.errors
	FEATURES="-collision-detect -protect-owned" emerge ${emergeOpts} -b -uDN --with-bdeps=y @world --ask=n

	echo "APPLYING NECCESSARY PRE-BUILD PATCHES"  >>/emerge.errors
	
	sh < /patches.sh

	#rm /patches.sh

	echo "DEPLOY::EMERGE PROFILE PACKAGES" >> /emerge.errors
	FEATURES="-collision-detect -protect-owned" emerge ${emergeOpts} $(cat /package.list)  2>>/emerge.errors
	#rm /package.list

	# Only used to instantiate a /var/lib/portage/.gnupg directory ... need more understanding of how keyserver is rolled in to udpating user space. and gentoo keys are refreshed
	# run getuto to buildup gpg
	#/usr/bin/getuto

	echo "DEPLOY::EMERGE ZED FILE SYSTEM"  >> /emerge.errors
	#emergeOpts="--verbose-conflicts"
	FEATURES="-getbinpkg -buildpkg" emerge ${emergeOpts} =zfs-9999 --nodeps  2>>/emerge.errors

	echo "DEPLOY::POST INSTALL UPDATE !!!"  >> /emerge.errors
	FEATURES="-collision-detect -protect-owned" emerge -b -uDN --with-bdeps=y @world --ask=n ${emergeOpts}  2>>/emerge.errors

	#wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

	# need to get variable from make.conf || emerge --info ... because eClean ? sucks ?
	rm ${_DISTDIR}/* -R

	eselect news read new 1>/dev/null  2>>/emerge.errors
	eclean distfiles
	eix-update
	updatedb
}

function deployServices() 
{
	echo "DEPLOY::EXECUTING SERVICE ROUTINE"  >>/emerge.errors
	sh < /services.sh  2>>/emerge.errors
	rm /services.sh
}

function deployLocales()
{
	# need a wrapper function for 'determining' locality, xml interface statements binded to URLs like https://ipinfo.io/
	# also, manual mechanism, via installer gui/script
 
    local key="${1:?}"
	echo "generating locales..."
	locale-gen -A >>/emerge.errors
	eselect locale set en_US.utf8

	printf "${colR}\n" "verify /etc/hosts file, which is patched, matches the correct server, otherwise nothing will be found on deployment..."  2>>/emerge.errors

	echo "emerge-webrsync ..." 2>>/emerge.errors
	emerge-webrsync 2>>/emerge.errors 

	eselect profile set default/linux/amd64/${key%/openrc}
	eselect profile show  2>>/emerge.errors

    echo "reading the news (null)..."  1>/dev/null  2>>/emerge.errors
	eselect news read all 1>/dev/null  2>>/emerge.errors
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data 2>>/emerge.errors
	
}

function tStamp() 
{
	echo "0x$(echo "obase=16; $(date +%s)" | bc)"
}

# PATCHFILES MUST INCLUDE PROVISIONING FOR 'PROFILES' / PER MACHINE/USER PROFILING
# PATCHFILES MUST NOT DELETE EXISTING CONFIGURATIONS
# ./update.sh / update -> updates system
# ./update.sh / profile -> updates profile on server
#	:: /etc/portage/... package server, must have an rsync method for saving profiles... Authenticated, based on machine PKI
# 	:: ./install.sh --> (can include URL for profile, local or remote to include hostname, existing public key)
#	:: need a method for delivering private key to new hosts, existing profiles. 'AUTHENTICATED' profiles
# need a key|oldap server, and a way to 'seed' authentication mechanisms with './install.sh'


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
	# because the repo hasn't been installed yet, cannot use getg2profile
	local _profile="${2}"

	psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"
	common_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/common" | sed 's/ //g' | sed "s/\"/'/g")"
	spec_URI="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/package http)/${_profile}" | sed 's/ //g' | sed "s/\"/'/g")"

	# -- delete would not preserve the profile soft link ? --keep-dirlinks ?
	mget "${psrc}/portage" "${offset}/etc/" #--keep-dirlinks --delete

	# if directories exist for new sources, zap them
	if [[ -d ${offset}/etc/portage/package.license ]];then rm "${offset}/etc/portage/package.license" -R; fi
	if [[ -d ${offset}/etc/portage/package.use ]];then rm "${offset}/etc/portage/package.use" -R; fi
	if [[ -d ${offset}/etc/portage/package.mask ]];then rm  "${offset}/etc/portage/package.mask" -R;fi
	if [[ -d ${offset}/etc/portage/package.unmask ]];then rm  "${offset}/etc/portage/package.unmask" -R;fi
	if [[ -d ${offset}/etc/portage/package.accept_keywords ]];then rm "${offset}/etc/portage/package.accept_keywords" -R;fi

	# if file exist for new sources, zap them
	if [[ -f ${offset}/etc/portage/package.license ]];then rm "${offset}/etc/portage/package.license"; fi
	if [[ -f ${offset}/etc/portage/package.use ]];then rm "${offset}/etc/portage/package.use"; fi

	if [[ -f ${offset}/etc/portage/package.mask ]];then rm  "${offset}/etc/portage/package.mask";fi
	if [[ -f ${offset}/etc/portage/package.unmask ]];then rm  "${offset}/etc/portage/package.unmask";fi
	if [[ -f ${offset}/etc/portage/package.accept_keywords ]];then rm "${offset}/etc/portage/package.accept_keywords";fi
	# compile common and spec rules in to /etc/portage/*.use|accept*|(un)mask|license
	echo -e "$(mget ${common_URI}.uses)\n$(mget ${spec_URI}.uses)" | uniq > ${offset}/etc/portage/package.use
	echo -e "$(mget ${common_URI}.keys)\n$(mget ${spec_URI}.keys)" | uniq > ${offset}/etc/portage/package.accept_keywords
	echo -e "$(mget ${common_URI}.mask)\n$(mget ${spec_URI}.mask)" | uniq > ${offset}/etc/portage/package.mask
	echo -e "$(mget ${common_URI}.unmask)\n$(mget ${spec_URI}.unmask)" | uniq > ${offset}/etc/portage/package.unmask
	echo "sh"
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
	# because the repo hasn't been installed yet, cannot use getg2profile
	local _profile="${2}"
	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"	
	mget "${psrc}/root/" "${offset}/root/" 
	mget "${psrc}/home/" "${offset}/home/" 
}

function patchFiles_sys() 
{
    local offset="${1:?}"
	# because the repo hasn't been installed yet, cannot use getg2profile
	local _profile="${2}"

	local psrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles rsync)"	

	mget "${psrc}/etc/" "${offset}/etc/" 
	mget "${psrc}/var/" "${offset}/var/" 
	mget "${psrc}/usr/" "${offset}/usr/"
	mget "${psrc}/*.[!.]*" "${offset}/"
	mget "${psrc}/srv/" "${offset}/"

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
	#local dir
	local mount_lines

	offset="$(echo "$1" | sed 's:/*$::')"

	#echo "offset = $offset"
	#sleep 10

	[[ -z "${offset}" ]] && { echo "cannot clear rootfs."; return; };

	procs="$(lsof "${offset}" 2>/dev/null | sed '1d' | awk '{print $2}' | uniq)" 
    sudodir="$(echo "${offset}" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | \grep "$offset" | wc -l)"

	#echo "procs = $procs"
	#echo "sudodir = $sudodir"
	#echo "mount_lines = $mount_lines"
	#echo "offset = $offset"
	#sleep 2

	if [[ -z ${offset} ]];then exit; fi	# this will break the local machine if it attempts to unmount nothing.

	# should require a --kill flag, to force kill processes within this mount.
	for process in ${procs}; do kill -9 "${process}"; done

	# this makes no sense, yet, I think its dangerous not to account for  /dev
	#if [[ -n "$(echo "${dir}" | \grep '/dev/')" ]]
	#then
	#	dir="${dir}"
	#else
	#	dir="${dir}/"
	#fi

	#echo "$dir";
	#sleep 10

	# 1 = pointer directory, leave mounted, if...
	while [[ "$mount_lines" != 0 ]]
	do
		while read -r mountpoint
		do
			#echo $mountpoint
			umount $mountpoint > /dev/null 2>&1
			#sleep 1
		done < <(cat /proc/mounts | \grep "$offset" | awk '{print $2}')
		mount_lines="$(cat /proc/mounts | \grep "$offset" | wc -l)"
	done

}

function mounts()
{
	local offset="${1:?}"
	local mSize="$(cat /proc/meminfo | column -t | \grep 'MemFree' | awk '{print $2}')"
	#mSize="${mSize}K"

	echo "msize = $mSize" 2>&1

	# do not constantly query ftp server at high frequency, bad things man.
	_kver=$(getKVER)
	echo "get kver = ${_kver}"
	#_kver=$(getKVER)

	# local only, no host
	# pkgHOST="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/host")"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/root")"

	[[ -z "$(cat /etc/mtab | grep "^proc ${offset%/}/proc")" ]] && {
		mount -t proc proc "${offset%/}/proc"		# proc /proc
		echo "mounted proc"
	} || { echo "/proc already exists ..."; };

	[[ -z "$(cat /etc/mtab | grep "^sysfs ${offset%/}/sys")" ]] && {
		mount --rbind /sys "${offset%/}/sys"		# sysfs /sys
		mount --make-rslave "${offset%/}/sys"
		echo "mounted sys"
	} || { echo "/sys already exists ..."; };

	[[ -z "$(cat /etc/mtab | grep "^udev ${offset%/}/dev")" ]] && {
		mount --rbind /dev "${offset%/}/dev"		# udev /dev
		mount --make-rslave "${offset%/}/dev"
		echo "mounted dev"
	} || { echo "/dev already exists ..."; };

	[[ -z "$(cat /etc/mtab | grep "^tmpfs ${offset%/}/tmp")" ]] && {
		mount -t tmpfs -o size=$mSize tmpfs "${offset%/}/tmp"	# tmpfs /tmp
		mount -t tmpfs tmpfs "${offset%/}/var/tmp"
		mount -t tmpfs tmpfs "${offset%/}/run"
		# /run/lock required for items like GPG, also required during package build|f/s generation
		mkdir -p "${offset%/}/run/lock/"
		echo "mounted mtab"
	} || { echo "/tmp already exists ..."; };

	echo "attempting to mount src & binpkgs..."

	# used to build packages which will be held outside the scope of a deployment

	echo "$_kver <<<"

	[[ ! -d ${offset%/}/usr/src/${_kver} ]] && { mkdir -p ${offset%/}/usr/src/${_kver}; echo "making ${_kver} @ ${offset%/}" ; };
	# eselect kernel set GETKVER ... can be reset. ... maybe ... possible conflict ??? requires sync before build ........ ? yes ... weird dependency route
	ln -sf ${_kver} ${offset%/}/usr/src/linux 
	#echo "overwriting kernel profile link..."

	[[ -z "$(cat /etc/mtab | grep "${offset%/}/usr/src/${_kver}" )" ]] && { 
		mount --bind ${pkgROOT}/source/ ${offset%/}/usr/src/${_kver}; 
		echo "mounted source ..."
	} || { echo "source already mounted ..."; };

	_BASEDIR="$(cat ${offset%/}/etc/portage/make.conf | \grep '^PKGDIR' | sed -e 's/\"//g')"
	_BASEDIR="${_BASEDIR#*=}";
	_BASEDIR="${_BASEDIR%/binpkgs*}";
	_PKGDIR="${_BASEDIR%/}/binpkgs/";
	_HOMEDIR="${_BASEDIR%/}/home/";
	_DISTDIR="${_BASEDIR%/}/distfiles";

	#echo "$pkgROOT :: $offset :: $_BASEDIR"

	[[ ! -d ${offset%/}${_PKGDIR} ]] && { echo "?..."; mkdir -p ${offset%/}${_PKGDIR}; }; 

	#cat /etc/mtab | grep "${offset%/}${_PKGDIR%/}"

	# NOT ALWAYS MOUNTING RIGHT !!!!

	#echo "${offset%/}${_PKGDIR%/}"

	[[ -z "$(cat /etc/mtab | grep "${offset%/}${_PKGDIR%/}")" ]] && { 
		mount --bind ${pkgROOT}/binpkgs/ ${offset%/}${_PKGDIR}; echo "mounted binpkgs"; 
	} || { echo "binpkgs already mounted ..."; };

	#echo "${offset%/}${_HOMEDIR%/}"

#####	BECAUSE EACH DEPLOYMENT REQUIRES LOCKING ON .pbx there needs to be made a copy, in to every deployment.
#		1st stage, rote copy to, with default key.
#		1.5 stage, mechanisms for authenticating, manually assigning gnupg keys.
#		2nd stage, mechanism for auth-key server instantiation/authentication

#	[[ -z "$(cat /etc/mtab | grep "${offset%/}${_HOMEDIR%/}")" ]] && { 
#		mount --bind ${pkgROOT}/home/ ${offset%/}${_HOMEDIR}; echo "mounted home"; 
#	} || { echo "home already mounted ..."; };

	# stage 1
	echo "checking portage home ${_HOMEDIR}" 
	mget ${pkgROOT}/home/ ${offset%/}${_HOMEDIR}

#	DISTFILES - OVER WEB/HTTP ... MUST BE, AND assigned in package/common.conf

	#[[ -z "$(cat /etc/mtab | grep "${offset%/}${_DISTDIR%/}")" ]] && { 
	#	mount --bind ${pkgROOT}/distfiles/ ${offset%/}${_DISTDIR}; echo "mounted distfiles"; 
	#} || { echo "distfiles already mounted ..."; };


	# mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/source "${offset}/usr/src/$(getKVER)"
	# mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/binpkgs "${offset}/var/lib/portage/binpkgs"
	# ensure sshfs links are persistent ... buggy shit.
	# sleep 3

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
	local kver="$(curl "$url_kernel" --silent --connect-timeout 5 | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep "\-gentoo" | sort -r | head -n 1 )" 
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
	local _arg="${2}"
	local _profile=""
	local result=""
	local _tmp=""

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

	_tmp="$(/usr/bin/eselect profile show | tail -n1)"
	_tmp="$(echo "${_tmp}" | sed -e 's/^[ \t]*//' | sed -e 's/\ *$//g')"

	case ${_arg} in
		'--arch')
			echo "$(yamlPath ${_tmp} 3 | awk '{print $1}')"
		;;
		'--version')
			echo "$(yamlPath ${_tmp} 4 | awk '{print $1}')"
		;;
		'--full')
			echo "$(yamlPath ${_tmp} 3 | awk '{print $3}')/${_profile}" 
		;;
		*)
			echo "${_profile}" 
		;;
	esac
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
