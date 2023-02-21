#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

pool=$1

clear_mounts $(getZFSMountPoint ${pool})

#zpool export ${pool}

