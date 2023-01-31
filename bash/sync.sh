#!/bin/bash

# backend data-server synchronization (no arguments) 
#
#   /var/lib/portage
#       /snapshots (snapshots from gentoo, [rsync] )
#       /releases (releases from gentoo [rsync] )
#       /distfiles (distfiles for gentoo [rsync] )
#       /repository (git repos for gentoo, plus associated)
#       /meta       ( meta package configuration files (for mpm.sh) )
#       /profiles   ( system profiles, for roaming/continuity/backup purposes )
#       /packages   ( binary packages, built by portage/emerge )
#       /kernels    ( 'official' kernel builds, for distribution )
#       /repos      (soft/hard link to maintained repo @ [/repository] )
#
#       https://www.gentoo.org/glep/glep-0074.html (MANIFESTS)   
#       


SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgserver/host")"
pkgROOT="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgserver/root")"
pkgCONF="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgserver/config")"

# initial condition calls for emerge-webrsync
syncURI="$(cat ${pkgCONF} | grep "^sync-uri")"
#syncLocation="$(cat ${pkgCONF} | grep "^location")"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/repos" rsync)"
#LOCATION="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgserver/repo")"
sed -i "s|^sync-uri.*|${URL}|g" ${pkgCONF}

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


printf "updating mlocate-db\n"
/usr/bin/updatedb
/usr/bin/eix-update

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"

printf "############################### [ META ] ########################################\n"
mget "--exclude='.*'" "rsync://${pkgHOST}/gentoo/meta/"       "${pkgROOT}/meta"
printf "############################### [ PROFILES ] ####################################\n"
mget "--exclude='.*'" "rsync://${pkgHOST}/gentoo/profiles/"   "${pkgROOT}/profiles" 
printf "############################### [ PACKAGES ] ####################################\n"
mget "--exclude='.*'" "rsync://${pkgHOST}/gentoo/packages/"   "${pkgROOT}/packages" 
printf "############################### [ PATCHFILES ] ##################################\n"
mget "--exclude='.*'" "rsync://${pkgHOST}/gentoo/patchfiles/" "${pkgROOT}/patckages"

owner="$(stat -c '%U' "${pkgROOT}")"
group="$(stat -c '%G' "${pkgROOT}")"

printf "setting ownership to {meta} ; {profiles} ; {packages}\n"

chown "${owner}:${group}" "${pkgROOT}/meta" -R			1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/profiles" -R		1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/packages" -R		1>/dev/null

#repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

for x in $(ls "${pkgROOT}/repository")
do
    printf "-------%s-------\n" ${x}
    git -C "${pkgROOT}/repository/${x}" fetch --all
    git -C "${pkgROOT}/repository/${x}" pull
done

#qmanifest -g
#gencache --jobs $(nproc) --update --repo ${repo##*/} --write-timestamp --update-pkg-desc-index --update-use-local-desc

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"

sed -i "s|HOST:.*|HOST: ${hostip}|g" /etc/rsync/rsyncd.motd
sed -i "s|DATE:.*|DATE: $(date)|g" /etc/rsync/rsyncd.motd

eix-update
updatedb