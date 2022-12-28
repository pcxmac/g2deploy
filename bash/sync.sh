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

echo "################################# [ REPOS ] #####################################"
URL="rsync://rsync.us.gentoo.org/gentoo-portage/"
echo -e "SYNCING w/ ***$URL*** [REPOS]"

unverified="none"
testCase="$(emerge --info | grep 'location:' | awk '{print $2}')/.tmp-unverified-download-quarantine"
#while [[ -n ${unverified} ]]
#do
#	emerge --sync | tee /var/log/esync.log
#    sleep 1
#    sync
#    if [[ -d  "${testCase}" ]];then echo "?" unverified=""; fi
#	ls ${testCase} -ail | grep 'tmp'
#	sleep 30
#done

emerge --sync | tee /var/log/esync.log


echo "############################### [ SNAPSHOTS ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/snapshots.mirrors" rsync)"
echo -e "SYNCING w/ $URL \e[25,42m[SNAPSHOTS]\e[0m";sleep 1
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group "${URL}" /var/lib/portage/ | tee /var/log/esync.log

echo "############################### [ RELEASES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/releases.mirrors" rsync only-sync)"
echo -e "SYNCING w/ $URL \e[25,42m[RELEASES]\e[0m";sleep 1
if [[ ! -d /var/lib/portage/releases ]]; then mkdir -p /var/lib/portage/releases; fi
find /var/lib/portage/releases/ -type l -delete
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group "${URL}${ARCH}" /var/lib/portage/releases | tee /var/log/esync.log

echo "############################### [ DISTFILES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/distfiles.mirrors" rsync)"
echo -e "SYNCING w/ $URL \e[25,42m[DISTFILES]\e[0m";sleep 1
rsync -avI --info=progress2 --timeout=300 --ignore-existing --ignore-times --no-perms --no-owner --no-group "${URL}" /var/lib/portage/ | tee /var/log/esync.log

echo "updating mlocate-db"
/usr/bin/updatedb
/usr/bin/eix-update

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"

pkgHOST="$(scanConfig ${SCRIPT_DIR}/config/host.cfg pkgserver host)"

mget "rsync://${pkgHOST}/gentoo/meta/*"		    "${SCRIPT_DIR}/meta/"
mget "rsync://${pkgHOST}/gentoo/profiles/*"	    "${SCRIPT_DIR}/profiles/"
mget "rsync://${pkgHOST}/gentoo/packages/*"	    "${SCRIPT_DIR}/packages/"
mget "rsync://${pkgHOST}/gentoo/patchfiles/*"	"${SCRIPT_DIR}/patchfiles/"

owner="$(stat -c '%U' "${SCRIPT_DIR}")"
group="$(stat -c '%G' "${SCRIPT_DIR}")"

chown "${owner}:${group}" "${SCRIPT_DIR}/meta" -R			1>/dev/null
chown "${owner}:${group}" "${SCRIPT_DIR}/profiles" -R		1>/dev/null
chown "${owner}:${group}" "${SCRIPT_DIR}/packages" -R		1>/dev/null


repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

repo="/var/lib/portage/repository/*"

for x in $(ls "${repo%/*}")
do
    echo "-------${x}-------"
    git -C "${repo%/*}/${x}" fetch --all
    git -C "${repo%/*}/${x}" pull
done

#qmanifest -g
#gencache --jobs $(nproc) --update --repo ${repo##*/} --write-timestamp --update-pkg-desc-index --update-use-local-desc

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"
sed -i "s|HOST:.*|HOST: ${hostip}|g" /etc/rsync/rsyncd.motd
sed -i "s|DATE:.*|DATE: $(date)|g" /etc/rsync/rsyncd.motd

eix-update
updatedb