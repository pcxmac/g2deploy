#!/bin/bash

# backend data-server synchronization (no arguments) 
#
#   /server:pkgROOT

#       ---- FETCH FROM INTERNET <<< INSTANTIABLE
#       /snapshots (snapshots from gentoo, [rsync] )
#       /releases (releases from gentoo [rsync] )
#       /distfiles (distfiles for gentoo [rsync] )

#       --- BUILT INTERNALLY, BY INTERNAL META RULES <<< INSTANTIABLE
#       /kernels    ( 'official' kernel builds, for distribution )
#       /source
#       /binpkgs

#       --- USER DISCRETIONARY, FETCH FROM INTERNET (have to clone first, future yaml config ?)
#       /repository (git repos for gentoo, plus associated)

#       --- INITIALLY SOURCED FROM THIS REPO, SYNC'S to HOST.CFG PKG.SERVER  (deploy to)
#       /meta       ( meta package configuration files (for mpm.sh) )
#       /profiles   ( system profiles, for roaming/continuity/backup purposes )
#       /packages   ( binary packages, built by portage/emerge )
#       /patchfiles ( custom binaries and text files, for patching over regular portage files, ie, bugs that are only resolved locally )


#
#       https://www.gentoo.org/glep/glep-0074.html (MANIFESTS)   
#       


SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/host")"
pkgROOT="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root")"
pkgCONF="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/config")"

checkHosts

# initial condition calls for emerge-webrsync
syncURI="$(cat ${pkgCONF} | grep "^sync-uri")"
#syncLocation="$(cat ${pkgCONF} | grep "^location")"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/repos" rsync)"
#LOCATION="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/repo")"
sed -i "s|^sync-uri.*|${URL}|g" ${pkgCONF}

printf "############################ [ BINARY PACKAGES ] #################################\n"
[[ ! -d ${pkgROOT}/binpkgs ]] && { mkdir -p ${pkgROOT}/binpkgs; };
emaint binhost --fix
# needs more work !!! zomg.

#sed -i "s|^location.*|location = ${LOCATION}|g" ${pkgCONF}
printf "################################# [ REPOS ] #####################################\n"
printf "SYNCING w/ ***%s***" "${URL}"
emerge --sync | tee /var/log/esync.log
sed -i "s|^sync-uri.*|${syncURI}|g" ${pkgCONF}
#sed -i "s|^location.*|${syncLocation}|g" ${pkgCONF}

# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/snapshots" rsync)"
printf "############################### [ SNAPSHOTS ] ###################################\n"
printf "SYNCING w/ ***%s***" "${URL}"
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" rsync only-sync)"
printf "############################### [ RELEASES ] ###################################\n"
printf "SYNCING w/ ***%s***" "${URL}"
if [[ ! -d "${pkgROOT}"/releases ]]; then mkdir -p "${pkgROOT}"/releases; fi
find "${pkgROOT}"/releases/ -type l -delete
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group "${URL}${ARCH}" "${pkgROOT}"/releases | tee /var/log/esync.log

# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/distfiles" rsync)"
printf "############################### [ DISTFILES ] ###################################\n"
printf "SYNCING w/ ***%s***" "${URL}"
rsync -avI --info=progress2 --timeout=300 --ignore-existing --ignore-times --no-perms --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

# build the latest kernel
printf "########################## [ KERNEL | SOURCE ] ###################################\n"
[[ -z "$(find "${pkgROOT}/kernels/" -maxdepth 2 -type f -exec echo Found file {} \;)" ]] && {

    _kver=$(getKVER);
    _kver="${_kver#*linux-}";

    echo "$_kver..."

    mkdir -p ${pkgROOT}/kernels/current/${_kver};
    mkdir -p ${pkgROOT}/kernels/deprecated;
    mkdir -p ${pkgROOT}/kernels/compat;
    zcat /proc/config.gz > ${pkgROOT}/kernels/current/${_kver}/config.default;

    echo "zcats"

}

echo "found files ?"

[[ -z "$(find "${pkgROOT}/source/" -maxdepth 2 -type f -exec echo Found file {} \;)" ]] && { mkdir -p ${pkgROOT}/source; };

echo "building kernels..."

# ASSUMES boot is automounted, or already mounted @ /boot
build_kernel / 



printf "updating mlocate-db\n"
/usr/bin/updatedb
/usr/bin/eix-update

# host.cfg uses 'pkgROOT' as a localizable variable, must be defined, before 'eval' the key values, dependent on 'pkgROOT'

printf "############################### [ META ] ########################################\n"
#mget "--delete --exclude='.*'" "rsync://${pkgHOST}/gentoo/meta/"       "${SCRIPT_DIR}/meta"
_meta="$(eval echo "$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root/meta")")"
mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/meta"        "${_meta}"
#echo "mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/meta"        "${_meta}""

printf "############################### [ PROFILES ] ####################################\n"
#mget "--delete --exclude='.*'" "rsync://${pkgHOST}/gentoo/profiles/"   "${SCRIPT_DIR}/profiles" 
_profiles="$(eval echo "$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root/profiles")")"
mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/profiles"    "${_profiles}"
#echo "mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/profiles"    "${_profiles}""

printf "############################### [ PACKAGES ] ####################################\n"
#mget "--delete --exclude='.*'" "rsync://${pkgHOST}/gentoo/packages/"   "${SCRIPT_DIR}/packages" 
_packages="$(eval echo "$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root/packages")")"
mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/packages"    "${_packages}"
#echo "mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/packages"    "${_packages}""

printf "############################### [ PATCHFILES ] ##################################\n"
#mget "--delete --exclude='.*'" "rsync://${pkgHOST}/gentoo/patchfiles/" "${SCRIPT_DIR}/patchfiles"
_patchfiles="$(eval echo "$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root/patchfiles")")"
#echo "mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/patchfiles"  "${_patchfiles}""
mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/patchfiles"  "${_patchfiles}"

sleep 30

owner="$(stat -c '%U' "${pkgROOT}")"
group="$(stat -c '%G' "${pkgROOT}")" 

printf "setting ownership to {meta} ; {profiles} ; {packages}\n"

chown "${owner}:${group}" "${pkgROOT}/meta" -R			1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/profiles" -R		1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/packages" -R		1>/dev/null

#repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

for x in $(ls "${pkgROOT}/repository")
do
    printf "%s\n" "${x}"
    git -C "${pkgROOT}/repository/${x}" fetch --all
    git -C "${pkgROOT}/repository/${x}" pull
done

#qmanifest -g
#gencache --jobs $(nproc) --update --repo ${repo##*/} --write-timestamp --update-pkg-desc-index --update-use-local-desc

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | head -n 1 | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"

sed -i "s|HOST:.*|HOST: ${hostip}|g" /etc/rsync/rsyncd.motd
sed -i "s|DATE:.*|DATE: $(date)|g" /etc/rsync/rsyncd.motd
sed -i "s|HTTP:.*|HTTP: http://${pkgHOST}|g" /etc/rsync/rsyncd.motd
sed -i "s|RSYNC:.*|RSYNC: rsync://${pkgHOST}/gentoo-portage/|g" /etc/rsync/rsyncd.motd
sed -i "s|FTP:.*|FTP: ftp://${pkgHOST}|g" /etc/rsync/rsyncd.motd

eix-update
updatedb