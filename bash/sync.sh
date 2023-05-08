#!/bin/bash

# full sync, can connect to a dedicated sync-server/dom-0, to use a minimal repo, sync and delete older missing off of distant server files

# backend data-server synchronization (no arguments) 
#
#   /server:pkgROOT

#       ---- FETCH FROM INTERNET <<< INSTANTIABLE
#  >        /snapshots (snapshots from gentoo, [rsync] )
#  >        /releases (releases from gentoo [rsync] )
#  >        /distfiles (distfiles for gentoo [rsync] )
#  >        /repos

#       --- BUILT INTERNALLY, BY INTERNAL META RULES <<< INSTANTIABLE
#  >        /kernels    ( 'official' kernel builds, for distribution )
#  >        /source
#  >        /binpkgs

#       --- USER DISCRETIONARY, FETCH FROM INTERNET (have to clone first, future yaml config ?)
#  >        /repository (git repos for gentoo, plus associated)

#       --- INITIALLY SOURCED FROM THIS REPO, SYNC'S to HOST.CFG PKG.SERVER  (deploy to)
#  >        /meta       ( meta package configuration files (for mpm.sh) )
#  >        /profiles   ( system profiles, for roaming/continuity/backup purposes )
#  >        /packages   ( binary packages, built by portage/emerge )
#  >        /patchfiles ( custom binaries and text files, for patching over regular portage files, ie, bugs that are only resolved locally )

#
#       https://www.gentoo.org/glep/glep-0074.html (MANIFESTS)   
#

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/host")"
pkgROOT="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root")"
pkgCONF="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/config")"
pkgARCH="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/arch")"
pkgREPO="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repo")"

makeCONF="/etc/portage/make.conf"
#reposCONF="/etc/portage/repos.conf/gentoo.conf"

repoLocation="$(cat /etc/portage/make.conf | grep '^PORTDIR')"
repoLocation="$(echo ${repoLocation#*=} | tr -d '"')"

checkHosts

printf "syncing portage ...\n"
patchFiles_portage / 

# initial condition calls for emerge-webrsync
syncURI="$(cat ${pkgCONF} | grep "^sync-uri")"
#syncLocation="$(cat ${pkgCONF} | grep "^location")"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/repos" rsync)"

#LOCATION="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/repo")"

printf "############################ [ BINARY PACKAGES ] #################################\n"
[[ ! -d ${pkgROOT}/binpkgs ]] && { mkdir -p ${pkgROOT}/binpkgs; };
emaint binhost --fix
# needs more work !!! zomg.

portDIR="$(cat ${makeCONF} | grep '^PORTDIR')"
rPortDIR="$(cat ${pkgCONF} | grep '^location')"

printf "################################## [ REPOS ] #####################################\n"
#printf "SYNCING w/ ***%s***\n" "${URL} | ${makeCONF} | ${pkgCONF} | ${portDIR} | ${rPortDIR} | ${pkgREPO} | ${syncURI}"

[[ ! -d ${pkgREPO} ]] && { mkdir -p ${pkgREPO}; };

sed -i "s|^sync-uri.*|sync-uri = ${URL}|g" ${pkgCONF}
sed -i "s|^PORTDIR.*|PORTDIR=\"${pkgREPO}\"|g" ${makeCONF}
sed -i "s|^location.*|location = ${pkgREPO}|g" ${pkgCONF}

emerge --sync | tee /var/log/esync.log

sed -i "s|^sync-uri.*|${syncURI}|g" ${pkgCONF}
sed -i "s|^PORTDIR.*|${portDIR}|g" ${makeCONF}
sed -i "s|^location.*|${rPortDIR}|g" ${pkgCONF}

# NO FILTERING FOR ARCH, THESE ARE TEXT-META FILES.
# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/snapshots" rsync)"
printf "################################ [ SNAPSHOTS ] ###################################\n"
printf "SYNCING w/ ***%s***\n" "${URL}"
[[ ! -d ${pkgROOT/snapshots} ]] && { mkdir -p ${pkgROOT/snapshots}; };
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial --append-verify --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

# ARCH = AMD64, X86, ...., * (ALL)
# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" rsync only-sync)"
printf "################################ [ RELEASES ] ####################################\n"
printf "SYNCING w/ ***%s***\n" "${URL}"
[[ ! -d ${pkgROOT/releases} ]] && { mkdir -p ${pkgROOT/releases}; };
find "${pkgROOT}"/releases/ -type l -delete
[[ ${pkgARCH} == "*" ]] && {
    rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial --append-verify --include="*/" --include="*${pkgARCH}*" --exclude="*" --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log;
} || {
	echo "$URL :: ${pkgROOT}/"
	sleep 10
    rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial --append-verify --include="*/" --include="*${pkgARCH}*" --exclude="*" --no-owner --no-group "${URL}" "${pkgROOT}"/releases/ | tee /var/log/esync.log;
};

# NO FILTERING FOR ARCH, THESE ARE TYPICALLY SOURCE FILES/TEXT TO BE COMPILED, OR DATAFILES WHICH ARE CROSS PLATFORM...
# initial condition calls for non-recursive sync
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/distfiles" rsync)"
printf "############################### [ DISTFILES ] ###################################\n"
printf "SYNCING w/ ***%s***\n" "${URL}"
[[ ! -d ${pkgROOT/distfiles} ]] && { mkdir -p ${pkgROOT/distfiles}; };
rsync -avI --info=progress2 --timeout=300 --ignore-existing --partial --append-verify --ignore-times --no-perms --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

printf "########################### [ ... sync ... ] ####################################\n"
printf "updating mlocate-db\n"

/usr/bin/updatedb
/usr/bin/eix-update

# host.cfg uses 'pkgROOT' as a localizable variable, must be defined, before 'eval' the key values, dependent on 'pkgROOT'
# build the latest kernel
printf "########################## [ KERNEL | SOURCE ] ###################################\n"
# instantiate directories, if none exist
[[ ! -d ${pkgROOT/source} ]] && { mkdir -p ${pkgROOT}/source/depricated; mkdir -p ${pkgROOT}/source/current; };
[[ ! -d ${pkgROOT/kernels} ]] && { mkdir -p ${pkgROOT}/kernels; };

[[ -z "$(ls -ail ${pkgROOT}/kernels --ignore . --ignore .. 2>/dev/null)" ]] && {

    _kver=$(getKVER);
    _kver="${_kver#*linux-}";

    mkdir -p ${pkgROOT}/kernels/current/${_kver};
    mkdir -p ${pkgROOT}/kernels/deprecated;
    mkdir -p ${pkgROOT}/kernels/compat;
    zcat /proc/config.gz > ${pkgROOT}/kernels/current/${_kver}/config.default;
};

[[ -z "$(ls -ail ${pkgROOT}/source/ --ignore . --ignore .. 2>/dev/null)" ]] && { mkdir -p ${pkgROOT}/source; };

# ASSUMES boot is automounted, or already mounted @ /boot

emerge --sync --verbose --backtrack=99 --ask=n
eix-update

build_kernel / 

# SCRIPT_DIR represents the root of the rsync/ftp/http server, plus or if, a few directories
#printf "############################### [ REPOS ] #######################################\n"
#mget "--delete --exclude='.*'" "rsync://${pkgHOST}/gentoo/meta/"       "${SCRIPT_DIR}/meta"
#_meta="$(eval echo "$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root/meta")")"
#mget "--delete --exclude='.*'"  "${repoLocation}"        "${SCRIPT_DIR}/repos/"
#echo "mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/meta"        "${_meta}""

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
mget "--owner --group --delete --exclude='.*'"  "${SCRIPT_DIR}/patchfiles"  "${_patchfiles}"

sleep 3

owner="$(stat -c '%U' "${pkgROOT}")"
group="$(stat -c '%G' "${pkgROOT}")" 

printf "setting ownership to {meta} ; {profiles} ; {packages}\n"

chown "${owner}:${group}" "${pkgROOT}/meta" -R			1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/profiles" -R		1>/dev/null
chown "${owner}:${group}" "${pkgROOT}/packages" -R		1>/dev/null

#repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

[[ ! -d ${pkgROOT}/repository ]] && { mkdir -p ${pkgROOT}/repository; };

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
