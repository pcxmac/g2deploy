
#!/bin/bash

SCRIPT_DIR="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function update_runtime()
{
	echo "UPDATE::RUNTIME_UPDATE !"
	exclude_atoms="-X sys-fs/zfs-kmod -X sys-fs/zfs"
	eselect profile show
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
		
	sudo emerge -b -uDN --with-bdeps=y @world --ask=n --binpkg-respect-use=y --binpkg-changed-deps=y ${exclude_atoms}
	eselect news read new
	
}

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



			if [[ ${directory} == "/" ]]
			then
				update_runtime
			else
				clear_mounts "${directory}"
				mounts "${directory}"
				chroot "${directory}" /bin/bash -c "update_runtime"
				clear_mounts "${directory}"
			fi
			patchFiles_sys "${directory}" "${_profile}"
	;;
	esac
done

echo "#############################"

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
				echo "edit boot -- ${kversion}" "${dataset}" "${directory}"
				editboot "${kversion}" "${dataset}" "${directory}"
				echo "install modules -- ${directory}"
				install_modules "${directory}"
				umount "${directory}/boot"
			else
				echo "no mas"
			fi
		;;
	esac
done

