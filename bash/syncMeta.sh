#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ./include.sh

echo "script dir = ${SCRIPT_DIR}"

#
#
#	fix the destination, last slash, and replicating the same directory in itself
#
#

mget rsync://10.1.0.1/gentoo/meta/*			${SCRIPT_DIR}/meta/
mget rsync://10.1.0.1/gentoo/profiles/*		${SCRIPT_DIR}/profiles/
mget rsync://10.1.0.1/gentoo/packages/*		${SCRIPT_DIR}/packages/
mget rsync://10.1.0.1/gentoo/patchfiles/*	${SCRIPT_DIR}/patchfiles/

owner="$(stat -c '%U' ${SCRIPT_DIR})"
group="$(stat -c '%G' ${SCRIPT_DIR})"

chown ${owner}:${group} ${SCRIPT_DIR}/meta -R			1>/dev/null
chown ${owner}:${group} ${SCRIPT_DIR}/profiles -R		1>/dev/null
chown ${owner}:${group} ${SCRIPT_DIR}/packages -R		1>/dev/null
chown ${owner}:${group} ${SCRIPT_DIR}/patchfiles -R		1>/dev/null
