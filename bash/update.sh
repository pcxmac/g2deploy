
#!/bin/bash

SCRIPT_DIR="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function update_runtime() {

	echo "executing RUNTIME_UPDATE !"
	exclude_atoms="-X sys-fs/zfs-kmod -X sys-fs/zfs"
	eselect profile show
	sudo emerge --sync --verbose --backtrack=99 --ask=n;sudo eix-update
	
	echo "PATCHING UPDATES"

	if [[ -f /patches.sh ]]
	then
		sh < /patches.sh
		rm /patches.sh
	fi

	echo "EMERGE MISSING PACKAGES"
	if [[ -f /package.list ]]
	then
		emerge ${emergeOpts} $(cat /package.list)
		rm /package.list
	fi

	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"

	if [[ "${av##*-}" != "${pv##*-}" ]]
	then 
		emerge portage --oneshot --ask=n
	fi
		
	sudo emerge -b -uDN --with-bdeps=y @world --ask=n --binpkg-respect-use=y --binpkg-changed-deps=y "${exclude_atoms}"
	eselect news read new
	
}

export PYTHONPATH=""
export -f update_runtime

for x in "$@"
do
	case "${x}" in
		work=*)
			directory="$(getZFSMountPoint "${x#*=}")"
			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint "${rootDS}")"

			if [[ ${directory} == "${target}" ]]
			then
				echo "cannot update mounted root file system (ZFS) !"
				echo "**${directory}** ?? **${target}**"
				exit
			else
				echo "shazaam!"
				dataset="${x#*=}"
				_profile="$(getG2Profile "${directory}")"
			fi
		;;
	esac
done


emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"		

echo "PROFILE -- $_profile"

echo "${directory}"

if [[ ! -d ${directory} ]];then exit; fi

clear_mounts "${directory}"

kversion=$(getKVER)
kversion=${kversion#*linux-}

mounts "${directory}"

for x in $@
do
	case "${x}" in
		update)
			echo "patch_portage ${directory} ${_profile} "

			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint "${rootDS}")"

			patchFiles_portage "${directory} ${_profile}"

			pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"
			patchSystem "${_profile}" 'update' > "${directory}/patches.sh"

			chroot "${directory}" /bin/bash -c "update_runtime"

			patchFiles_sys "${directory}" "${_profile}"
	;;
	esac
done

for x in "$@"
do
	case "${x}" in
		bootpart=*)
			efi_part="${x#*=}"
			type_part="$(blkid "${efi_part}")"
			if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
			then
				echo "update boot ! @ ${efi_part} @ ${dataset} :: ${directory} >> + $(getKVER)"

				echo "mount ${efi_part} ${directory}/boot"
				mount "${efi_part}" "${directory}/boot"
				echo "....."
				editboot "${kversion}" "${dataset}"
				install_modules "${directory}"
			else
				echo "no mas"
			fi
		;;
	esac
done

clear_mounts "${directory}"
