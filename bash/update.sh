
#!/bin/bash

SCRIPT_DIR="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function update_kernel()
{
	local _kver="$(getKVER)"
	pkgHOST="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgserver/host")"
	pkgROOT="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgserver/root")"

	efi_part="${1:?}"
	# gets rid of trailing slash in order to fit with next sequence.
	_directory="$(printf '%s\n' "${2:?}" | sed 's/\/$//g')"
	type_part="$(blkid "${efi_part}")"

	if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
	then
		# mount boot partition
		echo "update boot ! @ ${efi_part} @ ${dataset} :: ${_directory} >> + $(getKVER)"
		echo "mount ${efi_part} ${_directory}/boot"
		mount "${efi_part}" "${_directory}/boot"
		# edit boot record, refind
		echo "edit boot -- ${kversion}" "${dataset}" "${_directory}"
		editboot "${kversion}" "${dataset}" "${_directory}/"
		echo "install modules -- ${_directory}/"

		# install kernel modules to runtime
		install_modules "${_directory}/"

		# assert new initramfs
		mount -t fuse.sshfs -o uid=0,gid=0,allow_other root@${pkgHOST}:${pkgROOT}/source/ "${_directory}/usr/src/"
		chroot "${_directory}/" /usr/bin/eselect kernel set ${_kver}
		chroot "${_directory}/" /usr/bin/genkernel --install initramfs --compress-initramfs-type=lz4 --zfs
		mv ${_directory}/boot/initramfs-${_kver#*linux-}.img ${_directory}/boot/LINUX/${_kver#*linux-}/initramfs
		# unmount the boot partition
		umount "${_directory}/boot"
	else
		echo "no mas"
	fi
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

return

export PYTHONPATH=""
export -f update_runtime

dataset="$(getZFSDataSet /)"
directory="/"

checkHosts

# target user space. 
for x in "$@"
do
	case "${x}" in
		work=*)
			directory="$(getZFSMountPoint "${x#*=}")"
			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint "${rootDS}")"

			if [[ ${directory} == "${target}" ]]
			then
				dataset="$(getZFSDataSet /)"
				directory="/"
				echo "updating rootfs @ ${dataset} :: ${directory}"
			else
				#echo "shazaam!"
				dataset="${x#*=}"
			fi
		;;
	esac
done

_profile="$(getG2Profile "${directory}")"
emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"		

echo "PROFILE -- $_profile"
echo "${directory}"

if [[ ! -d ${directory} ]];then exit; fi

kversion=$(getKVER)
kversion=${kversion#*linux-}


# execute update
for x in $@
do
	case "${x}" in
		update)
			echo "patch_portage ${directory} ${_profile} "

			sleep 10

			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint "${rootDS}")"

			# doesn't work well for specific installs
			#patchFiles_portage "${directory}" "${_profile}"

			pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"
			patchSystem "${_profile}" 'update' > "${directory}/patches.sh"
			patchFiles_portage "${directory}" "${_profile}"

			if [[ ${directory} == "/" ]]
			then
				update_runtime
			else
				clear_mounts "${directory}"
				mounts "${directory}"

				# networking -preworkup -- a prelude for a networking patch script, most likely only on install, but something like this
				# is required to build up the deployment ... thinking.
				pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgserver/host")"
				bldHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:buildserver/host")"
				pkgIP="$(getent ahostsv4 ${pkgHOST} | head -n 1 | awk '{print $1}')"
				bldIP="$(getent ahostsv4 ${bldHOST} | head -n 1 | awk '{print $1}')"
				sed -i "/${pkgHOST}$/c${pkgIP}\t${pkgHOST}" ${directory}/etc/hosts
				sed -i "/${bldHOST}$/c${bldIP}\t${bldHOST}" ${directory}/etc/hosts
				################ work around ############################################################################################# 

				chroot "${directory}" /bin/bash -c "update_runtime"
				patchFiles_sys "${directory}" "${_profile}"
				clear_mounts "${directory}"
			fi
		;;
	esac
done

# update and install need a genkernel function (for new or updated image files.)

# for x in $@
# do
# 	case "${x}" in
# 		# only builds a kernel, if it's on a master (ie access to [pkg.server/root/]source/... thru current context)
# 		--kernel)
# 			_kernels_current="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgserver/root")"
# 			[[ -d ${_kernels_current} ]] && { build_kernel ${directory}; } || { printf 'will pull from remote repo...'; }
# 		;;
# 	esac
# done

for x in "$@"
do
	case "${x}" in
		bootpart=*)

			efi_part="${x#*=}"
			update_kernel ${efi_part} ${directory}
		;;
	esac
done

