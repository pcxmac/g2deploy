
#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    # INPUTS
    #           WORK=chroot offset		- update working directory
	#			BOOT=
	#
	#
	#	future features :
	#		test to see if pool exists, add new zfs datasets if no dataset, other partition types.
	#		NEED A STRUCTURE TO CHECK CURRENT BOOT SETTING/VERIFY MODULE INSTALL, THEN RETROFIT TO NEW KERNEL IF APPLICABLE, IF NOT, DONT DO SHIT TO THE KERNEL
	#
	#	USE = ./update.sh work=pool/set boot=/dev/sdX update
	#	
	#	
	#	
	#	
	#	
	#	
	#	
	#	
	#	
	#	
	#	

source ${SCRIPT_DIR}/bash/include.sh

function update_runtime() {

	# Consider using a file for package exclusions, for upgrade, deploy
	#
	#
	#
	# commit
	#

	echo "executing RUNTIME_UPDATE !"
	exclude_atoms="-X sys-fs/zfs-kmod -X sys-fs/zfs"
	eselect profile show
	sudo emerge --sync --verbose --backtrack=99 --ask=n;sudo eix-update
	emerge portage --oneshot --ask=n
	sudo emerge -b -uDN --with-bdeps=y @world --ask=n --binpkg-respect-use=y --binpkg-changed-deps=y ${exclude_atoms}
	eselect news read new
	
}

export PYTHONPATH=""
export -f update_runtime

# DESIGNATE A WORKING DIRECTORY TO

for x in $@
do
	case "${x}" in
		work=*)
			directory="$(getZFSMountPoint ${x#*=})"
			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint ${rootDS})"

			if [[ ${directory} == ${target} ]]
			then
				echo "cannot update mounted root file system (ZFS) !"
				echo "**${directory}** ?? **${target}**"
				exit
			else
				echo "shazaam!"
				dataset="${x#*=}"
				profile="$(getG2Profile ${directory})"
			fi
		;;
	esac
done


emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"		

echo "PROFILE -- $profile"

#exit
#
#	ONLY SUPPORTS ZFS
#
#	PROFILE TRANSLATION ISSUES
#	issues with profile derivation ...
#	openrc = default/linux/amd64/17.1
#	selinux = ???
#

echo ${directory}

if [[ ! -d ${directory} ]];then exit; fi

clear_mounts ${directory}

kversion=$(getKVER)
kversion=${kversion#*linux-}

mounts ${directory}

# update
for x in $@
do
	case "${x}" in
		update)
			echo "patch_portage ${directory} ${profile} "
			#patchProcessor ${directory} ${profile}
			# zfs only
			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint ${rootDS})"

			patch_sys ${directory} ${profile}
			patch_portage ${directory} ${profile}
			chroot ${directory} /bin/bash -c "update_runtime"
	;;
	esac
done

for x in $@
do
	case "${x}" in
		bootpart=*)
			efi_part="${x#*=}"
			type_part="$(blkid ${efi_part})"
			if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
			then
				echo "update boot ! @ ${efi_part} @ ${dataset} :: ${directory} >> + $(getKVER)"
				# IS THIS WORKING ?? NOT UPDATING BOOT RECORD ON DIFFERENT SETS

				echo "mount ${efi_part} ${directory}/boot"
				mount ${efi_part} ${directory}/boot
				echo "....."
				editboot ${kversion} "${dataset}"
				install_modules ${directory}
			else
				echo "no mas"
			fi
		;;
	esac
done

clear_mounts ${directory}
