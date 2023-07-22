
#!/bin/bash

SCRIPT_DIR="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh


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

			#sleep 10

			rootDS="$(df / | tail -n 1 | awk '{print $1}')"
			target="$(getZFSMountPoint "${rootDS}")"

			# doesn't work well for specific installs
			#patchFiles_portage "${directory}" "${_profile}"

			pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"
			patchSystem "${_profile}" 'update' > "${directory}/patches.sh"

			echo "patching portage ..."
			patchFiles_portage "${directory}" "${_profile}"

			if [[ ${directory} == "/" ]]
			then
				update_runtime
			else

				echo "clear mounts"

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

#	
#	add a cleaning mechanism to update. purge shit dependencies
#	
#	

for x in "$@"
do
	case "${x}" in
		bootpart=*)
			mounts ${directory}

			efi_part="${x#*=}"

			echo "updating the kernel on ${efi_part}"
			
			update_kernel ${efi_part} ${directory}
			
			#echo "end of line..."
			clear_mounts ${directory}
		;;
	esac
done

