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

_flags="${1}"

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

# if initialization proceed with sync_initialize then exit script

if [[ ${1%%=/*} == "--initialize" ]]
then
    location="${1##*=}"
    echo "initializing ${location}"
    #if [[ ! -d ${location} ]]
    #then

    # generate host config ...


    #else
    #    echo "location : ${location} exists, exiting."
    #    exit
    exit
fi

#

checkHosts

# variables

pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/host")"
pkgROOT="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/root")"
pkgCONF="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/config")"
pkgARCH="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/arch")"
pkgREPO="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repo")"
makeCONF="/etc/portage/make.conf"
#reposCONF="/etc/portage/repos.conf/gentoo.conf"
repoLocation="$(cat /etc/portage/make.conf | grep '^PORTDIR')"
repoLocation="$(echo ${repoLocation#*=} | tr -d '"')"
printf "syncing portage ...\n"
#patchFiles_portage / $(getG2Profile /)
# initial condition calls for emerge-webrsync
syncURI="$(cat ${pkgCONF} | grep "^sync-uri")"
#syncLocation="$(cat ${pkgCONF} | grep "^location")"
URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/repos" rsync)"
portDIR="$(cat ${makeCONF} | grep '^PORTDIR')"
rPortDIR="$(cat ${pkgCONF} | grep '^location')"
#LOCATION="$(findKeyValue ${SCRIPT_DIR}/config/host.cfg "server:pkgROOT/repo")"

# execution

printf "##################################################################################\n"
printf "## \n"
printf "## \n"
printf "## Please ensure to edit repo package/patch files, in order to propagate outwards.\n"
printf "## \n"
printf "## \n"
printf "##################################################################################\n"
printf "\n"
printf "############################ [ BINARY PACKAGES ] #################################\n"
[[ ! -d ${pkgROOT}/binpkgs ]] && { mkdir -p ${pkgROOT}/binpkgs; };

emaint binhost --fix

chown "${owner}:${group}"   "${pkgROOT}/binpkgs"    -R	1>/dev/null
chmod a-X       "${pkgROOT}/binpkgs"                -R  1>/dev/null
chmod ugo+rX    "${pkgROOT}/binpkgs"                -R  1>/dev/null


if [[ $_flags != '--skip' ]]
then

    printf "################################## [ REPOS ] #####################################\n"

    printf "sync @ %s\n" "${URL}"

    [[ ! -d ${pkgREPO} ]] && { mkdir -p ${pkgREPO}; };

    sed -i "s|^sync-uri.*|sync-uri = ${URL}|g" ${pkgCONF}
    sed -i "s|^PORTDIR.*|PORTDIR=\"${pkgREPO}/\"|g" ${makeCONF}
    sed -i "s|^location.*|location = ${pkgREPO}|g" ${pkgCONF}

    #emerge --sync --quiet | tee /var/log/esync.log
    emerge --sync | tee /var/log/esync.log

    sed -i "s|^sync-uri.*|${syncURI}|g" ${pkgCONF}
    sed -i "s|^PORTDIR.*|${portDIR}|g" ${makeCONF}
    sed -i "s|^location.*|${rPortDIR}|g" ${pkgCONF}

    # overlays are maintained in the 'repos' folder, alongside the main ebuild tree...
    # all overlays are maintained by git, thus, a simple git-update will sufficec.
    # all overlays will be tracked by the host.cfg, as a list:item 
    # so findKeyValue .... will yield a list of the repos, 
    # first check, is if the repo exists. (directory)

    _overlay="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/overlays")"
    _overlays="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/overlays/-")"

    echo "overlay = $_overlay"
    echo "overlays : $_overlays"

    for x in $(echo "${_overlays}")
    do
        _repo="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/overlays/${x}")"
        printf "%s\n" "${_overlay}${x} @ ${_repo}"

        [[ ! "$(cd ${_overlay}${x};git remote get-url origin)" == ${_repo} ]] && {
            [[ -d ${_overlay}${x} ]] && { rm ${_overlay}${x} -R; };
            git -C "${_overlay}" clone ${_repo};
        } || {
            git -C "${_overlay}${x}" fetch --all;
            git -C "${_overlay}${x}" pull;
        };

    done

   #sleep 100

    chown "${owner}:${group}"   "${pkgROOT}/repos"      -R  1>/dev/null
    chmod a-X       "${pkgROOT}/repos"                  -R  1>/dev/null
    chmod ugo+rX    "${pkgROOT}/repos"                  -R  1>/dev/null

    # NO FILTERING FOR ARCH, THESE ARE TEXT-META FILES.
    # initial condition calls for non-recursive sync
    URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/snapshots" rsync)"
    printf "################################ [ SNAPSHOTS ] ###################################\n"
    printf "SYNCING w/ ***%s***\n" "${URL}"
    [[ ! -d ${pkgROOT/snapshots} ]] && { mkdir -p ${pkgROOT/snapshots}; };
    rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial \
        --append-verify --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

    chown "${owner}:${group}"   "${pkgROOT}/snapshots"  -R	1>/dev/null
    chmod a-X       "${pkgROOT}/snapshots"              -R  1>/dev/null
    chmod ugo+rX    "${pkgROOT}/snapshots"              -R  1>/dev/null

    # ARCH = AMD64, X86, ...., * (ALL)
    # initial condition calls for non-recursive sync
    URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" rsync only-sync)"
    printf "################################ [ RELEASES ] ####################################\n"
    printf "SYNCING w/ ***%s***\n" "${URL}"
    [[ ! -d ${pkgROOT/releases} ]] && { mkdir -p ${pkgROOT/releases}; };
    find "${pkgROOT}"/releases/ -type l -delete
    [[ ${pkgARCH} == "*" ]] && {
        rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial \
            --append-verify --exclude="*binpackages*"                                                           \
            --no-owner --no-group "${URL}" "${pkgROOT}"/releases/ | tee /var/log/esync.log;
    } || {
        echo "$URL :: ${pkgROOT}/"
        sleep 10
        rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --partial \
            --append-verify --include="*/" --include="*${pkgARCH}*" --exclude="*"  --exclude="*binpackages*"    \
            --no-owner --no-group "${URL}" "${pkgROOT}"/releases/ | tee /var/log/esync.log;
    };

    chown "${owner}:${group}"   "${pkgROOT}/releases"   -R	1>/dev/null
    chmod a-X       "${pkgROOT}/releases"               -R  1>/dev/null
    chmod ugo+rX    "${pkgROOT}/releases"               -R  1>/dev/null

    # NO FILTERING FOR ARCH, THESE ARE TYPICALLY SOURCE FILES/TEXT TO BE COMPILED, OR DATAFILES WHICH ARE CROSS PLATFORM...
    # initial condition calls for non-recursive sync

    URL="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/distfiles" rsync)"
    printf "############################### [ DISTFILES ] ###################################\n"
    printf "SYNCING w/ ***%s***\n" "${URL}"
    [[ ! -d ${pkgROOT/distfiles} ]] && { mkdir -p ${pkgROOT/distfiles}; };
    rsync -avI --info=progress2 --timeout=300 --ignore-existing --append-verify --ignore-times --partial \
        --no-perms --no-owner --no-group "${URL}" "${pkgROOT}"/ | tee /var/log/esync.log

    chown "${owner}:${group}"   "${pkgROOT}/distfiles"  -R	1>/dev/null
    chmod a-X       "${pkgROOT}/distfiles"              -R  1>/dev/null
    chmod ugo+rX    "${pkgROOT}/distfiles"              -R  1>/dev/null

fi

# host.cfg uses 'pkgROOT' as a localizable variable, must be defined, before 'eval' the key values, dependent on 'pkgROOT'
# build the latest kernel
printf "########################## [ KERNEL | SOURCE ] ###################################\n"

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





# instantiate directories, if none exist
[[ ! -d ${pkgROOT/source} ]] && { mkdir -p ${pkgROOT}/source/depricated; mkdir -p ${pkgROOT}/source/current; };
[[ ! -d ${pkgROOT/kernels} ]] && { mkdir -p ${pkgROOT}/kernels; };

[[ -z "$(ls -ail ${pkgROOT}/kernels --ignore . --ignore .. 2>/dev/null)" ]] && {

    _kver=$(getKVER);
    _kver="${_kver#*linux-}";

    mkdir -p ${pkgROOT}/kernels/current/${_kver};
    mkdir -p ${pkgROOT}/kernels/deprecated;
    mkdir -p ${pkgROOT}/kernels/compat;
    #zcat /proc/config.gz > ${pkgROOT}/kernels/current/${_kver}/config.default;
};

[[ -z "$(ls -ail ${pkgROOT}/source/ --ignore . --ignore .. 2>/dev/null)" ]] && { mkdir -p ${pkgROOT}/source; };

# ASSUMES boot is automounted, or already mounted @ /boot

eix-update

if [[ $_flags != '--skip' ]]
then
    emerge --sync --verbose --backtrack=99 --ask=n
    build_kernel / 

    chown "${owner}:${group}"   "${pkgROOT}/kernels"    -R	1>/dev/null
    chmod a-X       "${pkgROOT}/kernels"                -R  1>/dev/null
    chmod ugo+rX    "${pkgROOT}/kernels"                -R  1>/dev/null

    # keep original permissions from kernel build
    chown "${owner}:${group}"   "${pkgROOT}/source" -R	1>/dev/null
    #chmod a-X       "${pkgROOT}/source"             -R  1>/dev/null
    #chmod ugo+rX    "${pkgROOT}/source"             -R  1>/dev/null

fi


owner="portage"
group="portage"

printf "############################### [ META ] ########################################\n"

_meta="$pkgROOT/meta"

mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/meta/"        "${_meta}"
chown "${owner}:${group}"   "${pkgROOT}/meta"       -R	1>/dev/null
chmod a-X       "${pkgROOT}/meta"               -R  1>/dev/null
chmod ugo+rX    "${pkgROOT}/meta"               -R  1>/dev/null

printf "############################### [ PROFILES ] ####################################\n"

_profiles="$pkgROOT/profiles/"

mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/profiles/"    "${_profiles}"
chown "${owner}:${group}"   "${pkgROOT}/profiles"   -R	1>/dev/null
chmod a-X       "${pkgROOT}/profiles"               -R  1>/dev/null
chmod ugo+rX    "${pkgROOT}/profiles"               -R  1>/dev/null


printf "############################### [ PACKAGES ] ####################################\n"

_packages="$pkgROOT/packages/"

mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/packages/"    "${_packages}"
chown "${owner}:${group}"   "${pkgROOT}/packages"   -R	1>/dev/null
chmod a-X       "${pkgROOT}/packages"               -R  1>/dev/null
chmod ugo+rX    "${pkgROOT}/packages"               -R  1>/dev/null

printf "############################### [ PATCHFILES ] ##################################\n"

_patchfiles="$pkgROOT/patchfiles/"

mget "--delete --exclude='.*'"  "${SCRIPT_DIR}/patchfiles/"  "${_patchfiles}"

#chown "${owner}:${group}"   "${pkgROOT}/patchfiles" -R	1>/dev/null
# some files are executable in patchfiles, like bashrc @ ./portage
#chmod a-X       "${pkgROOT}/patchfiles"             -R  1>/dev/null
#chmod ugo+rX    "${pkgROOT}/patchfiles"             -R  1>/dev/null

printf "############################### [ REPOSITORY ] ##################################\n"
#repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

if [[ $_flags != '--skip' ]]
then
    [[ ! -d ${pkgROOT}/repository ]] && { mkdir -p ${pkgROOT}/repository; };
    
    _repository="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository")"
    _repositories="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository/-")"

    for x in $(echo "${_repositories}")
    do
        _repo="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/repository/${x}")"
        printf "%s\n" "${_repository}${x} @ ${_repo}"
        [[ ! "$(cd ${_repository}${x} 2>/dev/null;git remote get-url origin)" == ${_repo} ]] && {
            [[ -d ${_repository}${x} ]] && { rm ${_repository}${x} -R; };
            git -C "${_repository}" clone ${_repo} ${x};
        } || {
            git -C "${_repository}${x}" fetch --all;
            git -C "${_repository}${x}" pull;
        };
    done
fi

if [[ $_flags != '--skip' ]]
then
    _repository="$(findKeyValue "${SCRIPT_DIR}/config/repos.eselect" "repositories/")"
    _repositories="$(findKeyValue "${SCRIPT_DIR}/config/repos.eselect" "repositories/-")"

    for x in $(echo "${_repositories}")
    do
        _repo="$(findKeyValue "${SCRIPT_DIR}/config/repos.eselect" "repositories/${x}")"
        bad_repo="$(git ls-remote ${_repository}${x} 2>&1 | \grep 'fatal')";
        #echo ":: ${_repository}${x} @ ${_repo}"

        [[ -z ${bad_repo} ]] && {
            git -C "${_repository}${x}" fetch --all;
            git -C "${_repository}${x}" pull;
        } || {
            #echo "bad repo @ ${x} | ${bad_repo}";
            [[ -d ${_repository}${x} ]] && { rm ${_repository}${x} -R; };
            git -C "${_repository}" clone ${_repo} ${x};
        };

    done
fi

#qmanifest -g
#gencache --jobs $(nproc) --update --repo ${repo##*/} --write-timestamp --update-pkg-desc-index --update-use-local-desc

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | head -n 1 | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev ${hostip} | /usr/bin/awk '{print $3}')"

hostDataSet="$(echo "$pkgROOT" | sed 's,/$,,')"
hostDataSet="$(getZFSDataSet $hostDataSet)"
hostSize="$(zfs list ${hostDataSet} | tail -n1 | awk '{print $4}')";

hostJSON="$(curl -s https://ipinfo.io)"

sed -i "s|DATE:.*|DATE:\t\t$(date)|g" /etc/rsync/rsyncd.motd
sed -i "s|Storage:.*|Storage:\t${hostSize}|g" /etc/rsync/rsyncd.motd

if [[ -n ${hostJSON} ]]; then

    hostCity="$(echo "$hostJSON" | \grep 'city')";
    hostCity="$(echo ${hostCity#*:} | sed 's/[^A-Za-z]//g')";

    hostCountry="$(echo "$hostJSON" | \grep 'country')";
    hostCountry="$(echo ${hostCountry#*:} | sed 's/[^A-Za-z]//g')";

    hostRegion="$(echo "$hostJSON" | \grep 'region')";
    hostRegion="$(echo ${hostRegion#*:} | sed 's/[^A-Za-z]//g')";

    hostTZ="$(echo "$hostJSON" | \grep 'timezone')";
    hostTZ="$(echo ${hostTZ#*:} | sed 's/[^A-Za-z]//g')";

    hostReverse="$(echo "$hostJSON" | \grep 'hostname')";
    hostReverse="$(echo ${hostReverse#*:} | sed 's/[^A-Za-z]//g')";

    hostWIP="$(echo "$hostJSON" | \grep "\"ip\"")";
    hostWIP="$(echo ${hostWIP#*:} | sed 's/[^0-9.:a-f]//g')";

    hostPostal="$(echo "$hostJSON" | \grep 'postal')";
    hostPostal="$(echo ${hostPostal#*:} | sed 's/[^A-Za-z]//g')";

    hostOrg="$(echo "$hostJSON" | \grep 'org')";
    hostOrg="$(echo ${hostOrg#*:} | sed 's/[^A-Za-z]//g')";

    hostLoc="$(echo "$hostJSON" | \grep 'loc')";
    hostLoc="$(echo ${hostLoc#*:} | sed 's/[^A-Za-z]//g')";

    #sed -i "s|HTTP ACCESS:.*|HTTP ACCESS:\thttp://${pkgHOST}|g" /etc/rsync/rsyncd.motd
    #sed -i "s|FTP ACCESS:.*|FTP ACCESS:\tftp://${pkgHOST}|g" /etc/rsync/rsyncd.motd
    #sed -i "s|PORTAGE:.*|PORTAGE:\trsync://${pkgHOST}/gentoo-portage/|g" /etc/rsync/rsyncd.motd
    #sed -i "s|RELEASES:.*|RELEASES:\trsync://${pkgHOST}/gentoo-portage/|g" /etc/rsync/rsyncd.motd
    #sed -i "s|SNAPSHOTS:.*|SNAPSHOTS:\trsync://${pkgHOST}/gentoo-portage/|g" /etc/rsync/rsyncd.motd
    #sed -i "s|DISTFILES:.*|DISTFILES:\trsync://${pkgHOST}/gentoo-portage/|g" /etc/rsync/rsyncd.motd
    sed -i "s|Location:.*|Location:\t${hostCity}, ${hostRegion}, ${hostCountry}|g" /etc/rsync/rsyncd.motd
    sed -i "s|HOST:.*|HOST:\t\t${hostWIP}|g" /etc/rsync/rsyncd.motd

fi

printf "patching portage:\n"
patchFiles_portage / "$(getG2Profile /)"

printf "updating eix/mlocate...\n"
eix-update
updatedb
