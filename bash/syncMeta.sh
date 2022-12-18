#!/bin/bash

SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ./include.sh

mget /var/lib/portage/meta	    ${SCRIPT_DIR}/meta
mget /var/lib/portage/profiles	${SCRIPT_DIR}/profiles
mget /var/lib/portage/packages	${SCRIPT_DIR}/packages
